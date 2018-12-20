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
        io:format("psocket send:~p\n",[Msg_p]),
        case Msg_p of
            ["CON", Nombre] ->
                case add_nombre(Nombre,Nodos,self()) of
                    true -> Msg_c = "ERROR "++Nombre++"\n";
                    false-> Msg_c = "OK "++Nombre++"\n",gen_tcp:send(Rte,Msg_c),atiende(Sock,Pid_B,Nodos,Nombre)
                end;
            _ -> Msg_c = "ERROR \n"
        end,
        gen_tcp:send(Rte,Msg_c),io:format("psocket receive:~p \n ",[Msg_c]);
    _ -> ok
  end,
  psocket(Sock,Pid_B,Nodos).

atiende(Sock,Pid_B,Nodos,Nombre) ->
    receive
	{tcp,Rte,Msg} ->
		Msg_p = string:tokens([X || <<X>> <= Msg]," \r\n"),
        io:format("atiende send:~p\n",[Msg_p]),
		Pid_B ! {self(),nodo},
        receive
    		Nodo -> Pid = spawn(Nodo,pcomando,loop,[Nodos,Nombre]),Pid ! {Msg_p,self()}
        end,
        receive
            close -> io:format("llego bien \n"),gen_tcp:send(Rte,"OK BYE \n"),gen_tcp:close(Sock);
            Msg_c -> gen_tcp:send(Rte,Msg_c),io:format("atiende receive:~p \n ",[Msg_c])
        end;
    {upd,Msg} ->
        gen_tcp:send(Sock,Msg),io:format("atiende send:~p \n ",[Msg])
    end,
    atiende(Sock,Pid_B,Nodos,Nombre).

add_nombre(Nombre,Nodos,Rte) ->
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
	{bm,Nodo} ! {clave, Nombre, self()},
	receive
		Rta -> Rta
	end.

bmanager(Nombres,Partidas) ->
    receive
        {buscar_n,Nombre,Pid} ->
            Pid ! gb_trees:lookup(Nombre,Nombres),bmanager(Nombres,Partidas);
        {buscar_p,Partida,Pid} ->
            Pid ! gb_trees:lookup(Partida,Partidas),bmanager(Nombres,Partidas);
        {clave,Nombre,Pid}  ->
            Result  = case gb_trees:lookup(Nombre,Nombres) of
                {value,_} -> Pid ! true,Nombres;
                none      -> Pid ! false ,gb_trees:insert(Nombre,{Pid,[]},Nombres)
            end,
            bmanager(Result,Partidas);
        {add, {Pid_p,Nombre}, Pid} ->
            Result_n = case gb_trees:lookup(Nombre,Nombres) of
                {value,{Pid_n,Lista}}   -> Pid ! true, gb_trees:update(Nombre,{Pid_n,Lista ++ [Pid_p]},Nombres);
                none                    -> Pid ! false, Nombres
            end,
            bmanager(Result_n,Partidas);
        {new, {Nombre_p,Pid_p,Nombre}, Pid} ->
            Result_p = gb_trees:enter(Nombre_p,{Pid_p,{Nombre,vacio,[]}},Partidas),
            bmanager(Nombres,Result_p);
        {lista,Pid} ->
            Pid ! gb_trees:keys(Partidas),
            bmanager(Nombres,Partidas);
				{lista, Pid,Nodos} ->
            Resto_nodos = lists:delete(node(),Nodos),
            Listas = lists:flatten(
                Lista = lists:map(
                fun(Nodo) ->
                    {bm,Nodo} ! {lista,self()},
                    receive
                        Rta -> Rta
                    end
                end,Resto_nodos)
            ),
						Partidas_actuales = gb_trees:keys(Partidas),
						io:format("Listas: ~p locales: ~p  map:~p\n",[Listas, Partidas_actuales,Lista]),
						Respuesta = Listas++lists:flatten(Partidas_actuales),
						Pid !  Respuesta,
            bmanager(Nombres,Partidas);
        {acc, Nombre, Juegoid, Pid} ->
					io:format("Partidas: ~p\n",[Partidas]),
					io:format("Jugadores: ~p\n",[Nombres]),
          %falta agregar q cuando acepta una partida se agregue a su lista en niombres
					case gb_trees:lookup(Juegoid, Partidas) of
            {value,{Pid_p,{J1,vacio,Espect}}} ->
                case J1 =/= Nombre of
                    true ->io:format("estoy 1"),
                        Result_p = gb_trees:update(Juegoid,{Pid_p,{J1,Nombre,Espect}}, Partidas),
												Pid ! true,
												bmanager(Nombres,Result_p);
                    false ->io:format("estoy 2"),
                        Pid ! {false,invalid},
                        bmanager(Nombres,Partidas)
                    end;
						{value,{_,{J1,J2,Espect}}} ->io:format("estoy 3"),
		                    Pid ! {false,ocupada},
		                    bmanager(Nombres,Partidas);
						none ->
												io:format("estoy 4"),
		                    Pid ! {false,no_exist},
		                    bmanager(Nombres,Partidas);
						_ -> io:format("no entrenguel")
					end;
		{obs, Nombre, Partida, Pid} ->
			case gb_trees:lookup(Partida,Partidas) of
				{value, {Pid_p,{J1, J2, Espect}}} ->
          case lists:member(Nombre, Espect) of
              false ->
                  Espect_n = Espect++[Nombre],
                  Partidas_n = gb_trees:update(Partida,{Pid_p,{J1, J2, Espect_n}},Partidas),
                  Pid ! {ok, agregado},
                  bmanager(Nombres, Partidas_n);
              true -> Pid ! {false, ya_existe}, bmanager(Nombres, Partidas)
          end;
				none -> Pid ! {false, no_exist}, bmanager(Nombres, Partidas)
			end;
		{leave, Nombre, Partida, Pid} ->
			case gb_trees:lookup(Partida, Partidas) of
				{value, {Pid_p,{J1, J2, Espect}}} ->
                    case lists:member(Nombre, Espect) of
                        false ->
                            Pid ! {ok, no_encontrado}, bmanager(Nombres, Partidas);
												true ->
                            Espect_n = Espect--[Nombre],
                            Partidas_n = gb_trees:update(Partida,{Pid_p,{J1, J2, Espect_n}},Partidas),
                            Pid ! {ok, eliminado},
                            bmanager(Nombres, Partidas_n)
                    end;
				none -> Pid ! {false, no_exist}, bmanager(Nombres, Partidas)
      end;
      {bye,Pid,Nombre} -> case  gb_trees:lookup(Nombre,Nombres) of
                              {value,{Pid_n,Lista}} ->
                                  Result_p = delete(Lista,Partidas),
                                  Result_n = gb_trees:delete_any(Nombre,Nombres),
                                  Pid ! true,
                                  bmanager(Result_n,Result_p);
                              none -> Pid ! false, bmanager(Nombre,Partidas)
                        end;
    _ -> io:format("LA peor"),bmanager(Nombres,Partidas)
    end.
delete([],Partidas) -> Partidas;
delete([Partida|Lista],Partidas) ->
  delete(Lista,gb_trees:delete_any(Partida,Partidas)).
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
