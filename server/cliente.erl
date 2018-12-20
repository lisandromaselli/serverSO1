-module(cliente).
-compile(export_all).

init(Port,Msj)->
    SomeHostInNet = "localhost", % to make it runnable on one machine
    {ok, Sock} = gen_tcp:connect(SomeHostInNet, Port,
                                 [binary, {active,false}]),
    ok = gen_tcp:send(Sock, Msj),
    {ok,Msg} = gen_tcp:recv(Sock,0),
    io:format("Respuesta: [~p]~n", [[X || <<X>> <= Msg]]),
    ok = gen_tcp:close(Sock).

funcion(X) -> io:format("~p",[X]).


start() ->
  A = "asd",
  B = [1,2,3],

  funcion(tostring(A)++tostring(B)).
