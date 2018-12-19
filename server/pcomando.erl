-module(pcomando).
-compile(export_all).


loop(Nodos,Nombre) ->
    receive
    	{Msg,Rte}->
    		case Msg of
    			["CON"] ->
                    Rte ! "ERROR deslogueate\n";
    			["LSG"] ->
                io:format(" ~p ~p",[Nombre,Nodos]),
                case check_nombre(Nombre,Nodos) of
                    false -> Rte ! "ERROR "++Nombre++"\n";
                    true ->
                        bm ! {lista,self(),Nodos},
                        receive
                            Lista -> Rte ! "OK "++Nombre++" "++"["++Lista++"]"++"\n"
                        end
                end;
    			["NEW"] ->
                    case create_game(Nombre,Nodos) of
                        true            -> Rte ! "OK "++Nombre++"\n";
                        {false,exit}    -> Rte ! "ERROR "++Nombre++" partida ya creada"++"\n";
                        {false,no_exist}-> Rte ! "ERROR "++Nombre++" no registrado"++"\n"
                    end;
    			["ACC", Juegoid] ->
                    case check_nombre(Nombre,Nodos) of
                        false -> Rte ! "ERROR "++Nombre++" no registrado";
                        true ->
        					case accept_game(Nombre, Juegoid,Nodos) of
        						true -> Rte ! "OK "++Nombre++"\n";
        						{false,ocupada} -> Rte ! "ERROR "++Nombre++"partida ya ocupada"++"\n";
                                {false,no_exist} ->Rte ! "ERROR "++Nombre++" partida no existe"++"\n";
                                {false,invalid}  ->Rte ! "ERROR "++Nombre++" invalido"++"\n"
                            end
                    end;
    			["PLA", Juegoid, Jugada] ->
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
    			["OBS", Juegoid] ->
                    case check_nombre(Nombre,Nodos) of
                        false -> Rte ! "ERROR "++Nombre++" no registrado";
                        true ->
        					case obs(Nombre, Juegoid, Nodos) of
        						{false, no_exist} ->Rte !  "ERROR "++Nombre++" NO EXISTE PARTIDA";
                                {false,ya_existe} ->Rte !  "ERROR "++Nombre++" YA ESTA OBSERVANDO";
        						{ok, agregado} -> Rte ! "OK "++Nombre++" COMO OBSERVADOR"++"\n"
        					end
                    end;
    			["LEA", Juegoid] ->
                    case check_nombre(Nombre,Nodos) of
                        false -> Rte ! "ERROR "++Nombre++" no registrado";
                        true ->
                            case leave(Nombre, Juegoid, Nodos) of
        						{ok, eliminado} ->Rte !  "OK "++Nombre++" ABANDONO COMO OBSERVADOR"++"\n";
        						{ok, no_encontrado} -> Rte ! "ERROR "++Nombre++" NO ERA OBSERVADOR"++"\n";
        						{false, no_exist} -> Rte ! "ERROR "++Nombre++" NO EXISTE PARTIDA"++"\n"
        					end
                    end;
    			["BYE"] ->
                  bm ! {buscar_n,Nombre,self()},
                  receive
                    {value,{Pid,Lista}}  ->avisar(Lista,Nodos,Nombre);
                    none        -> ok
                  end,
                  bm ! {bye,self(),Nombre},
                  io:format("pepito saliendo"),
            						receive
            							true -> Rte ! "OK BYE";
                          false -> Rte ! "NO OK"
            						end;
            			_ -> Rte ! "COMANDO INVALIDO"
            		end
            end.

avisar([],_,_) -> ok;
avisar([Partida|Lista],Nodos,Nombre) ->
  io:format("estoy avisando a ~p",[Partida]),
  bm ! {buscar_p,Partida,self()},
  receive
    {value,{Nombre,vacio,Espect}} -> ok;
    {value,{vacio,Nombre,Espect}} -> ok;
    {value,{Nombre,J,Espect}} -> send_update([J]++Espect,Nodos,pid_to_list(Partida),bye);
    {value,{J,Nombre,Espect}} -> send_update([J]++Espect,Nodos,pid_to_list(Partida),bye);
    _ -> io:format("LA peor"),ok
  end,
  avisar(Lista,Nodos,Nombre).
check_nombre(Nombre,Nodos) ->
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
	{bm,Nodo} ! {buscar_n, Nombre, self()},
	receive
		{value,_} -> true;
        none -> false
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

obs(Nombre, Juegoid, Nodos) ->
	Partida = list_to_pid(Juegoid),
	Nodo = lists:nth(erlang:phash(Partida, length(Nodos)), Nodos),
	{bm, Nodo} ! {obs, Nombre, Partida, self()},
	receive
		Rta -> Rta
	end.

leave(Nombre, Juegoid, Nodos) ->
	Partida = list_to_pid(Juegoid),
	Nodo = lists:nth(erlang:phash(Partida, length(Nodos)), Nodos),
	{bm, Nodo} ! {leave, Nombre, Partida, self()},
	receive
		Rta -> Rta
	end.

send_update([],_,_,_) -> ok;
send_update([Nombre|Lista],Nodos,Juegoid,{win,Jugador}) ->
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
    {bm,Nodo} ! {buscar_n, Nombre, self()},
    receive
        {value,{Pid,_}} -> Pid ! {upd,"UPD "++Nombre++" "++Juegoid++" "++Jugador++" GANÓ\n"} ;
        none -> io:format("ERROR en espectadores")
    end,
    send_update(Lista,Nodos,Juegoid,{win,Jugador});
send_update([Nombre|Lista],Nodos,Juegoid,full) ->
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
    {bm,Nodo} ! {buscar_n, Nombre, self()},
    receive
        {value,{Pid,_}} -> Pid ! {upd,"UPD "++Nombre++" "++Juegoid++" EMPATE\n"} ;
        none -> io:format("ERROR en espectadores")
    end,
    send_update(Lista,Nodos,Juegoid,full);
send_update([Nombre|Lista],Nodos,Juegoid,{ok,ListaN}) ->
    io:format("~p \n",[Nombre]),
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
    {bm,Nodo} ! {buscar_n, Nombre, self()},
    receive
        {value,{Pid,_}} -> Pid ! {upd,"UPD "++Nombre++" "++Juegoid++" "++ListaN++"\n"};
        none -> io:format("ERROR en espectadores")
    end,
    send_update(Lista,Nodos,Juegoid,{ok,ListaN});
send_update([Nombre|Lista],Nodos,Juegoid,bye) ->
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
    {bm,Nodo} ! {buscar_n, Nombre, self()},
    receive
        {value,{Pid,_}} ->io:format("Nombre:~p Juegoid:~p",[Nombre,Juegoid]), Pid ! {upd,"UPD "++Nombre++" ABANDONOB "++Juegoid++"\n"};
        none -> io:format("ERROR en espectadores")
    end,
    send_update(Lista,Nodos,Juegoid,bye).
