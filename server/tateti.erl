-module(tateti).
-compile(export_all).
change_player(Jugador,Lista) ->
    case Jugador of
        j1  -> movem(j2,Lista);
        j2  -> movem(j1,Lista);
        _   -> error("algo se rompio")
    end.
movem(Jugador,Lista) ->
	receive
		{Jugador, Pid_J, Jugada} when Jugada >= 1; Jugada =< 9 ->
    		{status, St, ListaN} = meter(Jugador,Jugada, Lista),
				case St of
				    0   -> Pid_J ! {ok,ListaN},change_player(Jugador,ListaN);
                    1   -> Pid_J ! {win, ListaN};
					-1  -> Pid_J ! {full, ListaN};
                    2   -> Pid_J ! {invalid,ListaN},movem(Jugador,ListaN)
				end;
		{_,Pid_J,_} ->
            Pid_J ! {invalid,Lista},
            movem(Jugador,Lista)
	end.

init() ->
	Lista = [0,0,0,0,0,0,0,0,0],
    spawn(?MODULE, movem, [j1,Lista]).



isfull(ListaN) ->
	case lists:member(0, ListaN) of
        true  -> {status, 0, ListaN};
		false -> {status, -1, ListaN}
	end.

meter(Pl,Jugada ,Lista) ->
	case lists:nth(Jugada, Lista) == 0 of		% Pregunta si el lugar esta vacio
		true ->
			ListaN = lists:sublist(Lista, Jugada-1) ++ [Pl] ++ lists:nthtail(Jugada, Lista),
			case ListaN of
				[Pl,Pl,Pl,_,_,_,_,_,_] -> {status, 1, ListaN};
				[_,_,_,Pl,Pl,Pl,_,_,_] -> {status, 1, ListaN};
				[_,_,_,_,_,_,Pl,Pl,Pl] -> {status, 1, ListaN};
				[Pl,_,_,Pl,_,_,Pl,_,_] -> {status, 1, ListaN};
				[_,Pl,_,_,Pl,_,_,Pl,_] -> {status, 1, ListaN};
				[_,_,Pl,_,_,Pl,_,_,Pl] -> {status, 1, ListaN};
				[Pl,_,_,_,Pl,_,_,_,Pl] -> {status, 1, ListaN};
				[_,_,Pl,_,Pl,_,Pl,_,_] -> {status, 1, ListaN};
				_                      -> isfull(ListaN)
			end;
		false ->  {status, 2,Lista}%% Repetir jugada en otro lugar
	end.

funcion(A) ->
    receive
    {A,_} -> io:format("EXITO"),funcion(j2);
    _   -> io:format("FRACASO"),funcion(A)
end.
