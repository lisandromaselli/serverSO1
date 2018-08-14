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
                    case create_game(Nombre,Nodos) of
                        true            -> Rte ! "OK "++Nombre;
                        {false,exit}    -> Rte ! "ERROR "++Nombre++" partida ya creada";
                        {false,no_exist}-> Rte ! "ERROR "++Nombre++" no registrado"
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
		Rta -> Rta
	end.
create_game(Nombre,Nodos) ->
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
    {bm,Nodo} ! {buscar,Nombre,self()},
    receive
            {value,vacio}   ->
                Pid_p = tateti:init(),
                Nodo = lists:nth(erlang:phash(Pid_p,length(Nodos)),Nodos),
                {bm,Nodo} ! {new, {Pid_p,Nombre}, self()},
                receive
                    Rta -> Rta
                end;
            {value,Pid_p}   -> {false,exist};
            none            -> {false,no_exist}
    end.
