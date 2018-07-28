-module(pcomando).
-compile(export_all).


loop(Sock) ->
receive
	{tcp, Rem, Msg} -> 
		Nuevo = string:tokens([X || <<X>> <= Msg]," "),
		case Nuevo of
			["CON", Nombre] -> gen_tcp:send(Sock, "Bien");
			["LSG"] -> gen_tcp:send(Sock, "Tambien");
			["NEW"] -> ok;
			["ACC", Juegoid] -> ok;
			["PLA", Juegoid, Jugada] -> ok;
			["OBS", Juegoid] -> ok;
			["LEA", Juegoid] -> ok;
			["BYE"] -> ok;
			_ -> gen_tcp:send(Sock,"Error: comando no valido")
		end
		end,
		gen_tcp:close(Sock).
%loop(Sock).


init() ->
{ok, LSock} = gen_tcp:listen(8000, [binary, {active, true}]),
{ok, Sock} = gen_tcp:accept(LSock),
loop(Sock).