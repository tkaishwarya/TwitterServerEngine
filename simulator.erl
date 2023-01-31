-module(simulator).
-export[start/0].

start() ->
    io:fwrite("\n\n Simulator Running\n\n"),
    
    {ok, [Clients_Input]} = io:fread("\nNumber of clients to simulate: ", "~s\n"),
    {ok, [SubscribersListMax]} = io:fread("\nMaximum Number of Subscribers a client can have: ", "~s\n"),
    {ok, [ClientsDisconnected]} = io:fread("\nPercentage of clients to disconnect to simulate periods of live connection and disconnection ", "~s\n"),

    ClientsList = list_to_integer(Clients_Input),
    MaxSubscribers = list_to_integer(SubscribersListMax),
    DisconnectClients = list_to_integer(ClientsDisconnected),
    NumberToDisconnect = DisconnectClients * (0.01) * ClientsList,

    Main_Table = ets:new(messages, [ordered_set, named_table, public]),
    clientCreation(1, ClientsList, MaxSubscribers, Main_Table),

    %Clients = clientCreation(ClientsList),
    
    %start time
    Start_Time = erlang:system_time(millisecond),
    %checkAliveClients(Clients),
    %End time
    End_Time = erlang:system_time(millisecond),
    io:format("\nTime Taken to Converge: ~p milliseconds\n", [End_Time - Start_Time]).

checkAliveClients(Clients) ->
    Alive_Clients = [{C, C_PID} || {C, C_PID} <- Clients, is_process_alive(C_PID) == true],
    if
        Alive_Clients == [] ->
            io:format("\n Merged: ");
        true ->
            checkAliveClients(Alive_Clients)
    end.

% Function to spawn a client - and figure out its properties (UserName, NumTweets, NumSubscribe, PID)
clientCreation(Count, ClientsList, MaxSubcribers, Main_Table) ->    
    UserName = Count,
    NumTweets = round(floor(MaxSubcribers/Count)),
    NumSubscribe = round(floor(MaxSubcribers/(ClientsList-Count+1))) - 1,

    PID = spawn(client, test, [UserName, NumTweets, NumSubscribe, false]),

    ets:insert(Main_Table, {UserName, PID}),
    if 
        Count == ClientsList ->
            ok;
        true ->
            clientCreation(Count+1, ClientsList, MaxSubcribers, Main_Table)
    end.