-module(tateti).
-compile(export_all).

loop1() ->
	receive
		{one, Pid_J1, Jugada, Lista} when Jugada >= 1; Jugada =< 9 -> 
		Pid_mov = spawn(?MODULE,meter,[one, self(), Jugada, Lista]),
		receive
			{status, St, Pl, ListaN} ->
				case St of
					0 -> Pid_J1 ! {ListaN};
					1 -> Pid_J1 ! {one, ListaN};
					-1 -> Pid_J1 ! {full, ListaN}
				end;
		{one, Pid_J1, Jugada, Lista} -> loop1()
			end;
		_ -> loop1()
	end.

init() ->
	Lista = [0,0,0,0,0,0,0,0,0],
	Pid_J = spawn(?MODULE, movem, []),
	% Pruebas
	Pid_J ! {one, self(), 6, Lista},
	receive {X} -> io:format("Lista nueva: ~p~n", [X]) end,
	Pid_J ! {one, self(), 5, X},
	receive {X1} -> io:format("Lista nueva 2: ~p~n", [X1]) end,
	Pid_J ! {one, self(), 4, X1},
	receive {one, X2} -> io:format("Lista nueva 3: ~p~n", [X2]) end,
	ok.



isfull(Pl, Pid_Pl, ListaN) -> 
	case lists:member(0, ListaN) of 
		true -> Pid_Pl ! {status, 0, Pl, ListaN};
		false -> Pid_Pl ! {status, -1, Pl, ListaN}
	end.

meter(Pl, Pid_Pl, Jugada, Lista) ->
	case lists:nth(Jugada, Lista) == 0 of		% Pregunta si el lugar esta vacio
		true ->
			ListaN = lists:sublist(Lista, Jugada-1) ++ [Pl] ++ lists:nthtail(Jugada, Lista),
			% Comprobar si alguien gano.
			%io:format("Lista: ~p~n", [ListaN]),
			case ListaN of
				[Pl,Pl,Pl,_,_,_,_,_,_] -> Pid_Pl ! {status, 1, Pl, ListaN};
				[_,_,_,Pl,Pl,Pl,_,_,_] -> Pid_Pl ! {status, 1, Pl, ListaN};
				[_,_,_,_,_,_,Pl,Pl,Pl] -> Pid_Pl ! {status, 1, Pl, ListaN};
				[Pl,_,_,Pl,_,_,Pl,_,_] -> Pid_Pl ! {status, 1, Pl, ListaN};
				[_,Pl,_,_,Pl,_,_,Pl,_] -> Pid_Pl ! {status, 1, Pl, ListaN};
				[_,_,Pl,_,_,Pl,_,_,Pl] -> Pid_Pl ! {status, 1, Pl, ListaN};
				[Pl,_,_,_,Pl,_,_,_,Pl] -> Pid_Pl ! {status, 1, Pl, ListaN};
				[_,_,Pl,_,Pl,_,Pl,_,_] -> Pid_Pl ! {status, 1, Pl, ListaN};
				_ -> spawn(?MODULE, isfull, [Pl, Pid_Pl, ListaN]) 
			end;
		false -> io:format("Lugar ocupado. Elegir otro.")	%% Repetir jugada en otro lugar
	end.


movem() ->
loop1(),
%loop2(),
movem().