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
    			["LSG", Nombre] -> bm ! {lista, self()},
					Res = list_games(),
					Rte ! Res;
    			["NEW", Nombre] ->
                    Res = create_game(Nombre,Nodos),
                    if
                        Res -> Rte ! "OK "++Nombre;

                        true-> Rte ! "ERROR "++Nombre
                    end;
    			["ACC", Nombre, Juegoid] -> 
					Res = accept_game(Nombre, Juegoid),
					if 
						Res -> Rte ! "OK "++Nombre;
						
						true -> Rte ! "ERROR "++Nombre
					end;
    			["PLA", Nombre, Juegoid, Jugada] -> 
					Res = play(Nombre, Juegoid, Jugada),
					Rte ! Res;
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
    
list_games() ->
	bm ! {lista, self()},
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

accept_game(Nombre, Juegoid) ->
	bm ! {acc, Nombre, Juegoid, self()},
	receive 
		Rta -> ok
	end, 
	Rta.

play(Nombre, Juegoid, Jugada) ->
	bm ! {jugar, Nombre, Juegoid, Jugada, self()}, %% si la jugada es -1, se abandona el juego
	receive
		{ok,ListaN} -> "OK";
		{win, ListaN} -> "GANÓ";
		{full, ListaN} -> "EMPATE";
		{invalid,ListaN} -> "ERROR: lugar no válido";
		ok -> "ABANDONO EL JUEGO"
	end.
