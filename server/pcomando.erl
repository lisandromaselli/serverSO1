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
                        true    -> Rte ! "OK "++Nombre++"\n";
                        false   -> Rte ! "ERROR desconocido\n"
                    end;
    			["ACC", Juegoid] ->
                    case check_nombre(Nombre,Nodos) of
                        false -> Rte ! "ERROR "++Nombre++" no registrado\n";
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
                        {invalid,_} -> Rte ! "ERROR "++Nombre++" jugada inválida"++"\n";
                        {ok,ListaN} ->
                            Lista = lists:flatten([io_lib:format("~p,", [V]) || V <- ListaN]),
                            Rte ! "OK " ++Nombre++"["++Lista++"]\n",
                            notify(Juegoid,Nodos,{ok,Lista,Nombre});
                		{win, ListaN} ->
                            Rte ! "OK "++Nombre++" GANÓ\n",notify(Juegoid,Nodos,{win,Nombre});
                		{full, ListaN} ->
                            Rte ! "OK "++Nombre++" EMPATE\n",notify(Juegoid,Nodos,{full,Nombre});
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
                  Nodo = lists:nth(erlang:phash(Nombre, length(Nodos)), Nodos),
                  {bm,Nodo} ! {buscar_n,Nombre,self()},
                  receive
                    {value,{Pid,Lista}}  ->avisar(Lista,Nodos,Nombre);
                    none        -> ok
                  end,
                  {bm,Nodo} ! {bye,self(),Nombre},
            		receive
            			true -> Rte ! close;
                        false -> Rte ! "NO OK\n"
            		end;
            	_ -> Rte ! "COMANDO INVALIDO"
        	end
        end.

avisar([],_,_) -> ok;
avisar([Partida|Lista],Nodos,Nombre) ->
    io:format("~p",[is_pid(Partida)]),
    notify(pid_to_list(Partida),Nodos,{bye,Nombre}),
    avisar(Lista,Nodos,Nombre).
check_nombre(Nombre,Nodos) ->
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
	{bm,Nodo} ! {buscar_n, Nombre, self()},
	receive
		{value,_} -> true;
        none -> false
	end.


create_game(Nombre,Nodos) ->
    Pid_p = tateti:init(),
    Nombre_p = pid_to_list(Pid_p),
    io:format("Pid : ~p \n",[Pid_p]),
    Nodo_p = lists:nth(erlang:phash(Nombre_p,length(Nodos)),Nodos),
    {bm,Nodo_p} ! {new, {Nombre_p,Pid_p,Nombre}, self()},
    Nodo_n = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
    {bm,Nodo_n} ! {add, {Nombre_p,Nombre}, self()},
    receive
        Rta -> Rta
    end.

accept_game(Nombre, Partida,Nodos) ->
    Nodo_p = lists:nth(erlang:phash(Partida,length(Nodos)),Nodos),
    {bm,Nodo_p} ! {acc, Nombre,Partida, self()},
    Nodo_n = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
  	receive
  		true -> io:format("estoy aca"),{bm,Nodo_n} ! {add, {Partida,Nombre}, self()},
              receive
                Rta -> Rta
              end;
      Rta  -> Rta
  	end.

play(Nombre, Partida, Jugada,Nodos) ->
    Nodo = lists:nth(erlang:phash(Partida,length(Nodos)),Nodos),
    {bm,Nodo} ! {buscar_p,Partida,self()},
    {Jugada_i,_} = string:to_integer(Jugada),
    receive
        {value,{_,{_,vacio,_}}} -> {false,no_acc};
        {value,{Pid,{Nombre,J,Espect}}} ->
            Pid ! {j1, self(), Jugada_i},
            receive
                Rta -> Rta
            end;
        {value,{Pid,{J,Nombre,Espect}}} ->
            Pid ! {j2, self(), Jugada_i},
            receive
                Rta -> Rta
            end;
        {value,_} -> {false,no_permisson};
        none -> {false,no_exist}
    end.

obs(Nombre, Partida, Nodos) ->
	Nodo = lists:nth(erlang:phash(Partida, length(Nodos)), Nodos),
	{bm, Nodo} ! {obs, Nombre, Partida, self()},
	receive
		Rta -> Rta
	end.

leave(Nombre, Partida, Nodos) ->
	Nodo = lists:nth(erlang:phash(Partida, length(Nodos)), Nodos),
	{bm, Nodo} ! {leave, Nombre, Partida, self()},
	receive
		Rta -> Rta
	end.

send_update([],_,_) -> true;
send_update([Nombre|Lista],Nodos,Msg) ->
    io:format("sned_update: ~p\n",[Msg]),
    Nodo = lists:nth(erlang:phash(Nombre,length(Nodos)),Nodos),
    {bm,Nodo} ! {buscar_n, Nombre, self()},
    receive
        {value,{Pid,_}} -> Pid ! {upd,Msg};
        none -> ok
    end,
    send_update(Lista,Nodos,Msg).

notify(Partida,Nodos,Op) ->
    Nodo = lists:nth(erlang:phash(Partida, length(Nodos)), Nodos),
    {bm,Nodo} ! {buscar_p,Partida,self()},
    io:format("Partida a notificar:~p",[Partida]),
    receive
        {value,{_,{J1,vacio,_}}}   -> io:format("la peor");
        {value,{_,{J1,J2,Espect}}} ->
            io:format("~p ~p",[J1,J2]),
            case Op of
                {full,J1}       -> send_update(Espect ++ [J2],Nodos,"UPD "++Partida++" EMPATE\n");
                {full,J2}       -> send_update(Espect ++ [J1],Nodos,"UPD "++Partida++" EMPATE\n");
                {win,J1}        -> send_update(Espect ++ [J2],Nodos,"UPD "++J1++" GANO\n");
                {win,J2}        -> send_update(Espect ++ [J1],Nodos,"UPD "++J2++" GANO\n");
                {ok,ListaN,J1}  -> send_update(Espect ++ [J2],Nodos,"UPD "++J2++" "++Partida++" "++ListaN++"\n");
                {ok,ListaN,J2}  -> send_update(Espect ++ [J1],Nodos,"UPD "++J1++" "++Partida++" "++ListaN++"\n");
                {bye,J1}        -> send_update(Espect ++ [J2],Nodos,"UPD "++J1++" ABANDONO "++Partida++"\n" );
                {bye,J2}        -> send_update(Espect ++ [J1],Nodos,"UPD "++J2++" ABANDONO "++Partida++"\n" )
            end;
        none -> io:format("la peor"),false
    end.
