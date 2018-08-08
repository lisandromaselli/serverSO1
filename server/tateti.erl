-module(tateti).
-compile(export_all).

loop1() ->
	receive
		{p_one, Pid_J1, Jugada, Lista} when Jugada >= 1; Jugada =< 9 -> 
		spawn(?MODULE,meter,[p_one, Pid_J1, Jugada, Lista]);
		{p_one, Pid_J1, Jugada, Lista} -> loop1();
		{status, St, Pl, Lista} ->
			case St of
				0 -> io:format("Lista nueva: ~p~n", [Lista]), ok;
				1 -> ok;
				-1 -> fin
			end;
			%Pid_J1 ! {"gano",Lista};
		_ -> loop1()
	end.

init() ->
	Lista = [0,0,0,0,0,0,0,0,0],
	Pid_J = spawn(?MODULE, movem, []),
	% Pruebas
	Pid_J ! {p_one, Pid_J, 6, Lista}.



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
			io:format("Lista: ~p~n", [ListaN]),
			case ListaN of
				[Pl,Pl,Pl,_,_,_,_,_,_] -> {status, 1, Pl, ListaN};
				[_,_,_,Pl,Pl,Pl,_,_,_] -> {status, 1, Pl, ListaN};
				[_,_,_,_,_,_,Pl,Pl,Pl] -> {status, 1, Pl, ListaN};
				[Pl,_,_,Pl,_,_,Pl,_,_] -> {status, 1, Pl, ListaN};
				[_,Pl,_,_,Pl,_,_,Pl,_] -> {status, 1, Pl, ListaN};
				[_,_,Pl,_,_,Pl,_,_,Pl] -> {status, 1, Pl, ListaN};
				[Pl,_,_,_,Pl,_,_,_,Pl] -> {status, 1, Pl, ListaN};
				[_,_,Pl,_,Pl,_,Pl,_,_] -> {status, 1, Pl, ListaN};
				_ -> spawn(?MODULE, isfull, [Pl, Pid_Pl, ListaN]) 
			end;
		false -> io:format("Lugar ocupado. Elegir otro.")	%% Repetir jugada en otro lugar
	end.


movem() ->
loop1(),
%loop2(),
movem().