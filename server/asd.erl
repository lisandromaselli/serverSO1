-module(asd).
-compile(export_all).

mostrar() ->
	receive
		{A,_} -> io:format("~p",[A])
	end,
	mostrar().