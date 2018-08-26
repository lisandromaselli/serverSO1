-module(pcomando).
-compile(export_all).


loop(Nodos) ->
    receive
    	{Msg,Rte}->
    		case Msg of
    			["CON", Nombre] ->
                    case add_nombre(Nombre,Nodos) of
                        true -> Rte ! "ERROR "++Nombre;
                        false-> Rte ! "OK "++Nombre
                    end;
    			["LSG", Nombre] ->
                case check_nombre(Nombre,Nodos) of
                    false -> Rte ! "ERROR "++Nombre;
                    true ->
                        bm ! {lista,self(),Nodos},
                        receive
                            Lista -> Rte ! "OK "++Nombre++" "++"["++Lista++"]"
                        end
                end;
    			["NEW", Nombre] ->
                    case create_game(Nombre,Nodos) of
                        true            -> Rte ! "OK "++Nombre;
                        {false,exit}    -> Rte ! "ERROR "++Nombre++" partida ya creada";
                        {false,no_exist}-> Rte ! "ERROR "++Nombre++" no registrado"
                    end;
    			["ACC", Nombre, Juegoid] ->
                    case check_nombre(Nombre,Nodos) of
                        false -> Rte ! "ERROR "++Nombre++" no registrado";
                        true ->
        					case accept_game(Nombre, Juegoid,Nodos) of
        						true -> Rte ! "OK "++Nombre;
        						{false,ocupada} -> Rte ! "ERROR "++Nombre++"partida ya ocupada";
                                {false,no_exist} ->Rte ! "ERROR "++Nombre++" partida no existe";
                                {false,invalid}  ->Rte ! "ERROR "++Nombre++" invalido"
                            end
                    end;
    			["PLA", Nombre, Juegoid, Jugada] ->
                    case play(Nombre, Juegoid, Jugada,Nodos) of
                        {false,no_acc} -> Rte ! "ERROR "++Nombre++" partida no aceptada";
                        {false,no_exist} -> Rte ! "ERROR "++Nombre++" partida no existe";
                        {false,no_permisson} -> Rte ! "ERROR "++Nombre++" no tenes permiso";
                        {invalid,ListaN} -> Rte ! "ERROR "++Nombre++" jugada inválida";
                        {ok,ListaN} -> Rte ! "OK " ++Nombre++"["++lists:flatten([io_lib:format("~p,", [V]) || V <- ListaN])++"]";
                		{win, ListaN} -> Rte ! "OK "++Nombre++" GANÓ";
                		{full, ListaN} -> Rte ! "OK "++Nombre++" EMPATE";
                		ok -> Rte ! "OK "++Nombre++" ABANDONO EL JUEGO"
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
	{bm,Nodo} ! {buscar_n, Nombre, self()},
	receive
		{value,_} -> true;
        none -> false
	end.

add_nombre(Nombre,Nodos) ->
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
	{bm,Nodo} ! {clave, Nombre, self()},
	receive
		Rta -> Rta
	end.

create_game(Nombre,Nodos) ->
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
    {bm,Nodo} ! {buscar_n,Nombre,self()},
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

accept_game(Nombre, Juegoid,Nodos) ->
    Partida = list_to_pid(Juegoid),
    Nodo = lists:nth(erlang:phash(Partida,length(Nodos)),Nodos),
    {bm,Nodo} ! {acc, Nombre,Partida, self()},
	receive
		Rta -> Rta
	end.

play(Nombre, Juegoid, Jugada,Nodos) ->
    Partida = list_to_pid(Juegoid),
    Nodo = lists:nth(erlang:phash(Partida,length(Nodos)),Nodos),
    {bm,Nodo} ! {buscar_p,Partida,self()},
    {Jugada_i,_} = string:to_integer(Jugada),
    receive
        {value,{J1,vacio,_}} -> {false,no_acc};
        {value,{J1,J2,_}} ->
            case J1 == Nombre of
                true ->
                    Partida ! {j1, self(), Jugada_i },
                    receive
                        Rta -> Rta
                    end;
                false ->
                    case J2 == Nombre of
                        true ->
                            Partida ! {j2, self(), Jugada_i},
                            receive
                                Rta -> Rta
                            end;
                        false -> {false,no_permisson}
                    end
            end;
        none -> {false,no_exist}
    end.
