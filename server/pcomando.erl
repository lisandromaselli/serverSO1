-module(pcomando).
-compile(export_all).


loop(Nodos) ->
    receive
    	{Msg,Rte}->
    		case Msg of
    			["CON", Nombre] ->
                    Res = check_nombre(Nombre,Nodos),
                    if
                        Res -> Rte ! "ERROR "++Nombre;

                        true-> Rte ! "OK "++Nombre
                    end;
    			["LSG", Nombre] -> 	bm ! {lista, self()},
    								receive
    									Rta -> Rte ! Rta
    								end;
    			["NEW", Nombre] ->
                    Res = create_game(Nombre,Nodos),
                    if
                        Res -> Rte ! "ERROR "++Nombre;

                        true-> Rte ! "OK "++Nombre
                    end;
    			["ACC", Nombre, Juegoid] -> bm ! {acepta, Nombre, Juegoid, self()},
    										receive
    											Pid_j -> Pid_j ! {acepta, Nombre, Juegoid, self()}
    										end,
    										receive
    											Rta -> Rte ! Rta
    										end;
    			["PLA", Nombre, Juegoid, Jugada] -> bm ! {jugada, Nombre, Juegoid, Jugada, self()},
    												receive
    													Pid_j -> Pid_j ! {jugada, Nombre, Juegoid, Jugada, self()}
    												end,
    												receive
    													Rta -> Rte ! Rta
    												end;
    			["OBS", Nombre, Juegoid] -> bm ! {observador, Nombre, Juegoid, self()},
    										receive
    											Pid_j -> Pid_j ! {observador, Nombre, Juegoid, self()}
    										end,
    										receive
    											Rta -> Rte ! Rta
    										end;
    			["LEA", Nombre, Juegoid] -> bm ! {leave, Nombre, Juegoid, self()},
    										receive
    											Pid_j -> Pid_j ! {leave, Nombre, Juegoid, self()}
    										end,
    										receive
    											Rta -> Rte ! Rta
    										end;
    			["BYE"] -> 	bm ! {bye, self()},
    						receive
    							Pid_j -> Pid_j ! {bye, self()}
    						end,
    						Rte ! "OK BYE";
    			_ -> io:format("Problema"), exit(-1)
    		end
    end.


check_nombre(Nombre,Nodos) ->
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
	{bm,Nodo} ! {clave, Nombre, self()},
	receive
		Rta -> ok
	end,
    Rta.
create_game(Nombre,Nodos) ->
    Pid_p = tateti:init(),
    Nodo = lists:nth(erlang:phash(Pid_p,length(Nodos)),Nodos),
    {bm,Nodo} ! {new, {Pid_p,Nombre}, self()},
    receive
        Rta -> ok
    end,
    Rta.
