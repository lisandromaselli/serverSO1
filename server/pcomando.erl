-module(pcomando).
-compile(export_all).


loop(Sock) ->
receive
	{Msg,Rte}-> 
		%% Nuevo = string:tokens([X || <<X>> <= Msg]," "),
		case Msg of
			["CON", Nombre] -> 	check_nombre(Nombre, self()),
								receive
									Rta -> Rte ! Rta
								end;
			["LSG", Nombre] -> 	bm ! {lista, self()},
								receive
									Rta -> Rte ! Rta	
								end;
			["NEW", Nombre] -> 	bm ! {new, Nombre, self()},
								receive
									Pid_j -> Pid_j ! {new, Nombre, self()} %% tateti responde si pudo crearla
								end,
								receive
									Rta -> Rte ! Rta
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
			_ -> gen_tcp:send(Sock,"Error: comando no válido")
		end
		end,
		gen_tcp:close(Sock).
%loop(Sock).


check_nombre(Nombre, Pid) ->
	bm ! {clave, Nombre, self()},
	receive
		Rta -> Pid ! Rta
	end.

init() ->
{ok, LSock} = gen_tcp:listen(8000, [binary, {active, true}]),
{ok, Sock} = gen_tcp:accept(LSock),
loop(Sock).