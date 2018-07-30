-module(tateti).
-compile(export_all).

%{J1, Pid_J1, Jugada}

movem(Lista) ->
loop1(),
loop2(),
movem(Lista).


loop1()->
	receive
		{J1, Pid_J1, Jugada} ->
			if
				Jugada >= 1 and Jugada <= 9 -> % Meter en tabla
			;	true -> % Coordenada no valida
			end;
			Lista_m ..
			Pid_J1 ! {"gano",Lista}
		_ -> {"error"},loop1()
end.

loop2()->
	receive
		{J2, Pid_J2, Jugada} ->
			if
				Jugada >= 1 and Jugada <= 9 -> % Meter en tabla
			;	true -> % Coordenada no valida
			end
		_ -> {"error"},loop2()
	end.


init() ->
	Lista = [0,0,0,0,0,0,0,0,0],
	spawn(?MODULE, movem, [Lista]).

meter(Pl, Jugada, Lista) ->
	case lists:nth(Jugada, Lista) == 0 of		% Pregunta si el lugar esta vacio
		true ->
			ListaN = lists:sublist(Lista, Jugada-1) ++ [Pl] ++ lists:nthtail(Jugada, Lista),
			% Comprobar si alguien gano.
			case ListaN of
				[Pl,Pl,Pl,_,_,_,_,_,_] -> {1, Pl, ListaN};
				[_,_,_,Pl,Pl,Pl,_,_,_] -> {1, Pl, ListaN};
				[_,_,_,_,_,_,Pl,Pl,Pl] -> {1, Pl, ListaN};
				[Pl,_,_,Pl,_,_,Pl,_,_] -> {1, Pl, ListaN};
				[_,Pl,_,_,Pl,_,_,Pl,_] -> {1, Pl, ListaN};
				[_,_,Pl,_,_,Pl,_,_,Pl] -> {1, Pl, ListaN};
				[Pl,_,_,_,Pl,_,_,_,Pl] -> {1, Pl, ListaN};
				[_,_,Pl,_,Pl,_,Pl,_,_] -> {1, Pl, ListaN}
				_ -> spawn(?MODULE, isfull, [ListaN]) 
			end;
		false ->
			{0, Pl, ListaN}
	end.

isfull(ListaN) when lists:member(0, ListaN) == true -> {0, Pl, ListaN};
isfull(ListaN) when lists:member(0, ListaN) == false -> {-1, Pl, ListaN}.