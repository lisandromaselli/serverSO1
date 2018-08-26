%Se puede empezar implementando el dispatcher, psocket y una versión de
%pcomando que siempre termine con el mensaje ERROR no implementado.
-module(server).
-compile(export_all).

pstat(Nodos) ->
	receive after 1000 ->
		Carga = statistics(total_active_tasks),
		lists:foreach(fun(X) -> {pb,X} ! {node(),Carga} end,Nodos)
	end,
    pstat(Nodos).

pbalance(Dict) ->
	receive
	{Pid,nodo} 	->	Lista = dict:to_list(Dict),
					Lista = lists:sort(fun({A,B},{C,D}) -> B =< D end,Lista),
					Pid ! element(1,lists:nth(1,Lista));
	{Nodo,Carga} -> pbalance(dict:store(Nodo,Carga,Dict))
	end,
    pbalance(Dict).

psocket(Sock,Pid_B,Nodos) ->
	receive
	{tcp,Rte,Msg} ->
		Msg_p = string:tokens([X || <<X>> <= Msg]," \r\n"),
        io:format("psocket send:~p~n",[Msg_p]),
		Pid_B ! {self(),nodo},
    		receive
    			Nodo -> Pid = spawn(Nodo,pcomando,loop,[Nodos]),
    		            Pid ! {Msg_p,self()}
            end,
            receive
                Msg_c -> gen_tcp:send(Rte,Msg_c),io:format("psocket receive:~p ~n ",[Msg_c])
            end;
    {upd,Msg} ->
        gen_tcp:send(Sock,Msg),io:format("psocket send:~p ~n ",[Msg])
    end,
    psocket(Sock,Pid_B,Nodos).

bmanager(Nombres,Partidas) ->
    receive
        {buscar_n,Nombre,Pid} ->
            Pid ! gb_trees:lookup(Nombre,Nombres),bmanager(Nombres,Partidas);
        {buscar_p,Partida,Pid} ->
            Pid ! gb_trees:lookup(Partida,Partidas),bmanager(Nombres,Partidas);
        {clave,Nombre,Pid_n,Pid}  ->
            Result  = case gb_trees:lookup(Nombre,Nombres) of
                {value,_} -> Pid ! true,Nombres;
                none      -> Pid ! false ,gb_trees:insert(Nombre,Pid_n,Nombres)
            end,
            bmanager(Result,Partidas);
        {new, {Pid_p,Nombre}, Pid} ->
            Result_p = gb_trees:enter(Pid_p,{Nombre,vacio,[]},Partidas),
            Pid ! true,
            bmanager(Nombres,Result_p);
        {lista,Pid} ->
            Pid ! lists:map(fun(X) -> pid_to_list(X) end,gb_trees:keys(Partidas)),
            bmanager(Nombres,Partidas);
		{lista, Pid,Nodos} ->
            Resto_nodos = lists:delete(node(),Nodos),
            Listas = lists:flatten(
                lists:map(
                fun(Nodo) ->
                    {bm,Nodo} ! {lista,self()},
                    receive
                        Rta -> Rta
                    end
                end,Resto_nodos)
            ),
            Pid !  string:join(lists:append(Listas,lists:map(fun(X) -> pid_to_list(X) end,gb_trees:keys(Partidas))),","),
            bmanager(Nombres,Partidas);
        {acc, Nombre, Juegoid, Pid} ->
			case gb_trees:lookup(Juegoid, Partidas) of
                {value,{J1,vacio,Espect}} ->
                    case J1 =/= Nombre of
                        true ->
                            Result_p = gb_trees:update(Juegoid,{J1,Nombre,Espect}, Partidas),
                            Pid ! true,
                            bmanager(Nombres,Result_p);
                        false ->
                            Pid ! {false,invalid},
                            bmanager(Nombres,Partidas)
                        end;
				{value, {J1,J2,Espect}} ->
                    Pid ! {false,ocupada},
                    bmanager(Nombres,Partidas);
				none ->
                    Pid ! {false,no_exist},
                    bmanager(Nombres,Partidas)
			end
    end.

iniciador(Nodos) ->
	lists:foreach(fun(X) -> net_adm:ping(X) end,Nodos),
    Pid = spawn(?MODULE,bmanager,[gb_trees:empty(),gb_trees:empty()]),
    register(bm,Pid).

init(Port,Nodos) ->
	{ok,LSock} = gen_tcp:listen(Port,[binary,{active,true}]),
    iniciador(Nodos),
	Pid_B = spawn(?MODULE,pbalance,[dict:new()]),
	Pid_D = spawn(?MODULE,dispatcher,[LSock,Pid_B,Nodos]),
	spawn(?MODULE,pstat,[Nodos]),
	register(pb,Pid_B).

dispatcher(LSock,Pid_B,Nodos) ->
	{ok,Sock}  = gen_tcp:accept(LSock),
	Pid 	   = spawn(?MODULE, psocket, [Sock,Pid_B,Nodos]),
	gen_tcp:controlling_process(Sock, Pid),
	dispatcher(LSock,Pid_B,Nodos).
