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
		Msg_p = string:tokens([X || <<X>> <= Msg]," "),
        io:format("psocket send:~p~n",[Msg_p]),
		Pid_B ! {self(),nodo},
		receive
			Nodo -> Pid = spawn(Nodo,pcomando,loop,[Nodos]),
		            Pid ! {Msg_p,self()}
        end,
        receive
            Msg_c -> gen_tcp:send(Rte,Msg_c),io:format("psocket receive:~p ~n ",[Msg_c])
        end
    end,
    psocket(Sock,Pid_B,Nodos).

bmanager(Nombres,Partidas) ->
    receive
        {clave,Nombre,Pid}  ->
            Result  = case gb_trees:lookup(Nombre,Nombres) of
                {value,V} -> Pid ! true , Nombres;
                none      -> Pid ! false ,gb_trees:insert(Nombre,Pid,Nombres)
				end;
		{lista, Pid} -> Pid ! gb_trees:to_list(Partidas);
		{new, {Pid_p, Nombre}, Pid} -> gb_trees:insert(Pid_p, [Nombre], Partidas), Pid ! true;
		{acc, Nombre, Juegoid, Pid} -> 
			case gb_trees:lookup(Juegoid, Partidas) of
				{value, [J1]} -> if 
									J1 =/= Nombre -> gb_trees:update(Juegoid, [J1, Nombre], Partidas), Pid ! true;
									true -> Pid ! true
									end;
				_ -> Pid ! false
				end;
		{jugar, Nombre, Juegoid, Jugada, Pid} ->
			case gb_trees:lookup(Juegoid, Partidas) of
				{value, Jug} -> case Jugada of
									-1 -> gb_trees:update(Juegoid, Jug--Nombre, Partidas), Pid ! ok;
									_ -> Juegoid ! {Nombre, Pid, Jugada}
									end;
				none -> Pid ! {error, "No existe partida"}
				end;
    end,
bmanager(Result,Partidas).

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
