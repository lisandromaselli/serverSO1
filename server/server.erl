%Se puede empezar implementando el dispatcher, psocket y una versión de
%pcomando que siempre termine con el mensaje ERROR no implementado.
-module(server).
-compile(export_all).

pstat() ->
	receive after 1000 ->
		Carga = statistics(total_active_tasks),
		lists:foreach(fun(X) -> {pb,X} ! {node(),Carga} end,nodes()),
        pb ! {node(),Carga}
	end,
	pstat().
	

pbalance(Dict) -> 
	receive
	{Pid,nodo} 	->	Lista = dict:to_list(Dict),
					Lista = lists:sort(fun({A,B},{C,D}) -> B =< D end,Lista),
					Pid ! element(1,lists:nth(1,Lista));
	{Nodo,Carga} -> pbalance(dict:store(Nodo,Carga,Dict))
	end,
	pbalance(Dict).
psocket(Sock,Pid_B) ->
	receive
	{tcp,Rte,Msg} ->
		Msg_p = string:tokens([X || <<X>> <= Msg]," "), 
		Pid_B ! {self(),nodo},
		receive
			Nodo -> Pid = spawn(Nodo,server,pcomando,[]),
		            Pid ! {Msg_p,self()}
        end,
        receive
            Msg_c -> gen_tcp:send(Rte,Msg_c) 
        end
    end,
psocket(Sock,Pid_B).

bmanager() ->ok.

iniciador(Nodos) ->
	lists:foreach(fun(X) -> net_adm:ping(X) end,Nodos),
    Pid = spawn(?MODULE,bmanager,[]),    
    register(bm,Pid).

init(Port,Nodos) ->
	{ok,LSock} = gen_tcp:listen(Port,[binary,{active,true}]),
	Pid_B = spawn(?MODULE,pbalance,[dict:new()]),
	Pid_D = spawn(?MODULE,dispatcher,[LSock,Pid_B]),
	spawn(?MODULE,pstat,[]),
	register(pb,Pid_B),
	iniciador(Nodos).
	
dispatcher(LSock,Pid_B) ->
	{ok,Sock}  = gen_tcp:accept(LSock),
	Pid 	   = spawn(?MODULE, psocket, [Sock,Pid_B]),
	gen_tcp:controlling_process(Sock, Pid),
	dispatcher(LSock,Pid_B).
