%Se puede empezar implementando el dispatcher, psocket y una versión de
%pcomando que siempre termine con el mensaje ERROR no implementado.
-module(server).
-compile(export_all).

pstat(Pids) ->
	receive after 1000 ->
		Carga = statistics(total_active_tasks),
		lists:foreach(fun(X) -> X ! {node(),Carga} end,Pids)
	end,
	pstat(Pids).
	
	
findmin (Key,Value,Acc) ->
	min(Value,Acc).
pbalance(Dict) -> 
	receive
	{Pid,nodo} 	->	Lista = dict:to_list(Dict),
					Lista = lists:sort(fun({A,B},{C,D}) -> B =< D end,Lista),
					Pid ! element(2,lists:nth(1,Lista));
	{Nodo,Carga} -> pbalance(dict:store(Nodo,Carga,Dict))
	end,
	pbalance(Dict).

psocket(Sock,Pid_B) ->
	receive
	{tcp,Rte,Msg} ->
		Msg_p = string:tokens([X || <<X>> <= Msg]," "),
		Pid_B ! {self(),nodo},
		receive
			Nodo -> spawn(Nodo,server,pcomando,[Msg_p])
		end
	end,
psocket(Sock,Pid_B).

loop() ->
	receive
		{tcp,Rte,Msg} ->
			case string:tokens([X || <<X>> <= Msg]," ") of
				[A,B,C,D] 	-> gen_tcp:send(Rte,Msg), loop();
				[A,B,C]		-> ok;
				[A,B,C]		-> ok;
				_ -> gen_tcp:send(Rte,"asd"), io:format("[~p]",[Msg])
			end;
		X -> io:format("??[~p]~n",[X])
	end.

iniciador(Nodos) ->
	Pids = lists:map(fun(X) -> rpc:call(X,erlang,whereis,[pb]) end,Nodos),
	Pid_S = spawn(?MODULE,pstat,[Pids]).

init(Nodos) ->
	{ok,LSock} = gen_tcp:listen(8020,[binary,{active,true}]),
	Pid_B = spawn(?MODULE,pbalance,[dict:new()]),
	Pid_D = spawn(?MODULE,dispatcher,[LSock,Pid_B]),
	register(pb,Pid_B).
	%iniciador(Nodos).
	
dispatcher(LSock,Pid_B) ->
	{ok,Sock}  = gen_tcp:accept(LSock),
	Pid 	   = spawn(?MODULE, psocket, [Sock,Pid_B]),
	gen_tcp:controlling_process(Sock, Pid),
	dispatcher(LSock,Pid_B).
