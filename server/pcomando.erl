-module(pcomando).
-compile(export_all).


loop(Nodos) ->
    receive
    	{Msg,Rte}->
    		case Msg of
    			["CON", Nombre] ->
                    case add_nombre(Nombre,Nodos,Rte) of
                        true -> Rte ! "ERROR "++Nombre++"\n";
                        false-> Rte ! "OK "++Nombre++"\n"
                    end;
    			["LSG", Nombre] ->
                case check_nombre(Nombre,Nodos) of
                    false -> Rte ! "ERROR "++Nombre++"\n";
                    true ->
                        bm ! {lista,self(),Nodos},
                        receive
                            Lista -> Rte ! "OK "++Nombre++" "++"["++Lista++"]"++"\n"
                        end
                end;
    			["NEW", Nombre] ->
                    case create_game(Nombre,Nodos) of
                        true            -> Rte ! "OK "++Nombre++"\n";
                        {false,exit}    -> Rte ! "ERROR "++Nombre++" partida ya creada"++"\n";
                        {false,no_exist}-> Rte ! "ERROR "++Nombre++" no registrado"++"\n"
                    end;
    			["ACC", Nombre, Juegoid] ->
                    case check_nombre(Nombre,Nodos) of
                        false -> Rte ! "ERROR "++Nombre++" no registrado";
                        true ->
        					case accept_game(Nombre, Juegoid,Nodos) of
        						true -> Rte ! "OK "++Nombre;
        						{false,ocupada} -> Rte ! "ERROR "++Nombre++"partida ya ocupada"++"\n";
                                {false,no_exist} ->Rte ! "ERROR "++Nombre++" partida no existe"++"\n";
                                {false,invalid}  ->Rte ! "ERROR "++Nombre++" invalido"++"\n"
                            end
                    end;
    			["PLA", Nombre, Juegoid, Jugada] ->
                    case play(Nombre, Juegoid, Jugada,Nodos) of
                        {false,no_acc} -> Rte ! "ERROR "++Nombre++" partida no aceptada"++"\n";
                        {false,no_exist} -> Rte ! "ERROR "++Nombre++" partida no existe"++"\n";
                        {false,no_permisson} -> Rte ! "ERROR "++Nombre++" no tenes permiso"++"\n";
                        {{invalid,_},_} -> Rte ! "ERROR "++Nombre++" jugada inválida"++"\n";
                        {{ok,ListaN},Espect} ->
                            Lista = lists:flatten([io_lib:format("~p,", [V]) || V <- ListaN]),
                            Rte ! "OK " ++Nombre++"["++Lista++"]\n",
                            send_update(Espect,Nodos,Juegoid,{ok,Lista});
                		{{win, ListaN},Espect} ->
                            Rte ! "OK "++Nombre++" GANÓ\n",send_update(Espect,Nodos,Juegoid,{win,Nombre});
                		{{full, ListaN},Espect} ->
                            Rte ! "OK "++Nombre++" EMPATE\n",send_update(Espect,Nodos,Juegoid,full);
                		ok -> Rte ! "OK "++Nombre++" ABANDONO EL JUEGO\n"
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

add_nombre(Nombre,Nodos,Rte) ->
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
	{bm,Nodo} ! {clave, Nombre,Rte, self()},
	receive
		Rta -> Rta
	end.

create_game(Nombre,Nodos) ->
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
    {bm,Nodo} ! {buscar_n,Nombre,self()},
    receive
        {value,_}   ->
            Pid_p = tateti:init(),
            Nodo = lists:nth(erlang:phash(Pid_p,length(Nodos)),Nodos),
            {bm,Nodo} ! {new, {Pid_p,Nombre}, self()},
            receive
                Rta -> Rta
            end;
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
        {value,{_,vacio,_}} -> {false,no_acc};
        {value,{Nombre,J,Espect}} ->
            Partida ! {j1, self(), Jugada_i},
            receive
                Rta -> {Rta,[J]++Espect}
            end;
        {value,{J,Nombre,Espect}} ->
            Partida ! {j2, self(), Jugada_i},
            receive
                Rta -> {Rta,[J]++Espect}
            end;
        {value,_} -> {false,no_permisson};
        none -> {false,no_exist}
    end.
send_update([],_,_,_) -> ok;
send_update([Nombre|Lista],Nodos,Juegoid,{win,Jugador}) ->
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
    {bm,Nodo} ! {buscar_n, Nombre, self()},
    receive
        {value,Pid} -> Pid ! {upd,"UPD "++Nombre++" "++Juegoid++" "++Jugador++" GANÓ\n"} ;
        none -> io:format("ERROR en espectadores")
    end,
    send_update(Lista,Nodos,Juegoid,{win,Jugador});
send_update([Nombre|Lista],Nodos,Juegoid,full) ->
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
    {bm,Nodo} ! {buscar_n, Nombre, self()},
    receive
        {value,Pid} -> Pid ! {upd,"UPD "++Nombre++" "++Juegoid++" EMPATE\n"} ;
        none -> io:format("ERROR en espectadores")
    end,
    send_update(Lista,Nodos,Juegoid,full);
send_update([Nombre|Lista],Nodos,Juegoid,{ok,ListaN}) ->
    io:format("~p \n",[Nombre]),
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
    {bm,Nodo} ! {buscar_n, Nombre, self()},
    receive
        {value,Pid} -> Pid ! {upd,"UPD "++Nombre++" "++Juegoid++" "++ListaN++"\n"};
        none -> io:format("ERROR en espectadores")
    end,
    send_update(Lista,Nodos,Juegoid,{ok,ListaN}).
