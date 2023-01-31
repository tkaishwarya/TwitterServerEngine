-module(twitter_server_engine).
-import(maps, []).
-export[start/0].

start() ->
    io:fwrite("\n\n Twitter Enginer\n\n"),
    %Table = ets:new(t, [ordered_set]),
    Table = ets:new(messages, [ordered_set, named_table, public]),
    Client_Dictionary = ets:new(clients, [ordered_set, named_table, public]),
    Users_List = [],
    Map = maps:new(),
    {ok, ListenSocket} = gen_tcp:listen(1204, [binary, {keepalive, true}, {reuseaddr, true}, {active, false}]),
    await_connections(ListenSocket, Table, Client_Dictionary).

await_connections(Listen, Table, Client_Dictionary) ->
    {ok, Socket} = gen_tcp:accept(Listen),
    ok = gen_tcp:send(Socket, "YIP"),
    spawn(fun() -> await_connections(Listen, Table, Client_Dictionary) end),
    %conn_loop(Socket).
    received_t(Socket, Table, [], Client_Dictionary).

received_t(Socket, Table, Bs, Client_Dictionary) ->
    io:fwrite("Do Receive\n\n"),
    case gen_tcp:recv(Socket, 0) of
        {ok, Data1} ->
            
            Data = re:split(Data1, ","),
            Type = binary_to_list(lists:nth(1, Data)),

            io:format("\n\nDATA: ~p\n\n ", [Data]),
            io:format("\n\nTYPE: ~p\n\n ", [Type]),

            if 
                Type == "register" ->
                    UserName = binary_to_list(lists:nth(2, Data)),
                    PID = binary_to_list(lists:nth(3, Data)),
                    io:format("\nPID:~p\n", [PID]),
                    io:format("\nSocket:~p\n", [Socket]),
                    io:format("Type: ~p\n", [Type]),
                    io:format("\n~p wants to register an account\n", [UserName]),
                    
                    Output = ets:lookup(Table, UserName),
                    io:format("Output: ~p\n", [Output]),
                    if
                        Output == [] ->

                            ets:insert(Table, {UserName, [{"followers", []}, {"tweets", []}]}),      
                            ets:insert(Client_Dictionary, {UserName, Socket}),                
                            Temp_List = ets:lookup(Table, UserName),
                            io:format("~p", [lists:nth(1, Temp_List)]),

                          
                            ok = gen_tcp:send(Socket, "User has been registered"), % RESPOND BACK - YES/NO
                            io:fwrite("Not present in db, all clear\n");
                        true ->
                            ok = gen_tcp:send(Socket, "User already exists, please enter other username"),
                            io:fwrite("key already present\n")
                    end,
                    received_t(Socket, Table, [UserName], Client_Dictionary);

                Type == "tweet" ->
                    UserName = binary_to_list(lists:nth(2, Data)),
                    Tweet = binary_to_list(lists:nth(3, Data)),
                    io:format("\n ~p sent the following tweet: ~p", [UserName, Tweet]),
                    
                    % {ok, Val} = maps:find(UserName, Map),
                    Val = ets:lookup(Table, UserName),
                    io:format("Output: ~p\n", [Val]),
                    Val3 = lists:nth(1, Val),
                    Val2 = element(2, Val3),
                    Val1 = maps:from_list(Val2),
                    {ok, CurrentFollowers} = maps:find("followers",Val1),                         
                    {ok, CurrentTweets} = maps:find("tweets",Val1),

                    NewTweets = CurrentTweets ++ [Tweet],
                    io:format("~p~n",[NewTweets]),
                    
                    ets:insert(Table, {UserName, [{"followers", CurrentFollowers}, {"tweets", NewTweets}]}),
                  
                    sendMessage(Socket, Client_Dictionary, Tweet, CurrentFollowers, UserName),
                    received_t(Socket, Table, [UserName], Client_Dictionary);

                Type == "retweet" ->
                    Person_UserName = binary_to_list(lists:nth(2, Data)),
                    UserName = binary_to_list(lists:nth(3, Data)),
                    Sub_User = string:strip(Person_UserName, right, $\n),
                    io:format("User to retweet from: ~p\n", [Sub_User]),
                    Tweet = binary_to_list(lists:nth(4, Data)),
                    Out = ets:lookup(Table, Sub_User),
                    if
                        Out == [] ->
                            io:fwrite("User does not exist!\n");
                        true ->
                            % Current User
                            Out1 = ets:lookup(Table, UserName),
                            Val3 = lists:nth(1, Out1),
                            Val2 = element(2, Val3),
                            Val1 = maps:from_list(Val2),
                            % User we are retweeting from
                            Val_3 = lists:nth(1, Out),
                            Val_2 = element(2, Val_3),
                            Val_1 = maps:from_list(Val_2),
                            % current user
                            {ok, CurrentFollowers} = maps:find("followers",Val1),
                            % user we are retweeting from
                            {ok, CurrentTweets} = maps:find("tweets",Val_1),
                            io:format("Tweet to be re-posted: ~p\n", [Tweet]),
                            CheckTweet = lists:member(Tweet, CurrentTweets),
                            if
                                CheckTweet == true ->
                                    NewTweet = string:concat(string:concat(string:concat("re:",Sub_User),"->"),Tweet),
                                    sendMessage(Socket, Client_Dictionary, NewTweet, CurrentFollowers, UserName);
                                true ->
                                    io:fwrite("Tweet does not exist!\n")
                            end     
                    end,
                    io:format("\n ~p wants to retweet something", [UserName]),
                    received_t(Socket, Table, [UserName], Client_Dictionary);

                Type == "subscribe" ->
                    UserName = binary_to_list(lists:nth(2, Data)),
                    SubscribedUserName = binary_to_list(lists:nth(3, Data)),
                    Sub_User = string:strip(SubscribedUserName, right, $\n),

                    Output1 = ets:lookup(Table, Sub_User),
                    io:format("Output: ~p\n", [Output1]),

                    if
                        Output1 == [] ->
                            io:fwrite("The username entered doesn't exist! Please try again. \n");
                        true ->

                            Val = ets:lookup(Table, Sub_User),
                            io:format("~p~n",[Val]),
                            Val3 = lists:nth(1, Val),
                            Val2 = element(2, Val3),

                            Val1 = maps:from_list(Val2),                            
                            {ok, CurrentFollowers} = maps:find("followers",Val1),
                            {ok, CurrentTweets} = maps:find("tweets",Val1),

                            NewFollowers = CurrentFollowers ++ [UserName],
                            io:format("~p~n",[NewFollowers]),
                        
                            ets:insert(Table, {Sub_User, [{"followers", NewFollowers}, {"tweets", CurrentTweets}]}),

                            ok = gen_tcp:send(Socket, "Subscribed!"),

                            received_t(Socket, Table, [UserName], Client_Dictionary)
                    end,
                    io:format("\n ~p wants to subscribe to ~p\n", [UserName, Sub_User]),
                    ok = gen_tcp:send(Socket, "Subscribed!"),
                    received_t(Socket, Table, [UserName], Client_Dictionary);

                Type == "query" ->
                    Option = binary_to_list(lists:nth(3, Data)),
                    UserName = binary_to_list(lists:nth(2, Data)),
                    % Query = binary_to_list(lists:nth(3, Data)),
                    if
                        Option == "1" ->
                            io:fwrite("My mentions!\n");
                        Option == "2" ->
                            io:fwrite("Hashtag Search\n"),
                            Hashtag = binary_to_list(lists:nth(4, Data)),
                            io:format("Hashtag: ~p\n", [Hashtag]);
                        true ->
                            io:fwrite("Subscribed User Search\n"),
                            Sub_UserName = binary_to_list(lists:nth(4, Data)),
                            io:format("Sub_UserName: ~p\n", [Sub_UserName])
                    end,
                    io:format("\n ~p wants to query", [UserName]),
                    % Query_List = re:split(Query, " "),
                    % FirstWord = lists:nth(1, Query_List),
                    % io:format("First word is ~p\n", [FirstWord]),
                    % FirstLetter = string:slice(FirstWord, 0, 1),
                    % io:format("First letter is ~p\n", [FirstLetter]),
                    % if
                    %     FirstLetter == <<"@">> ->
                    %         % check for the mentioned user in the table
                    %         % if the user doesn't exist, write command invalid, please try again
                    %         % if the user exists, return his/hers tweets
                    %         % check for all the tweets, return the ones in which the user is mentioned

                    %         io:fwrite("@ symbol\n");
                    %     true ->
                    %         io:fwrite("No @ symbol\n")
                    % end,
                    received_t(Socket, Table, [UserName], Client_Dictionary);
                true ->
                    io:fwrite("\n Anything else!")
            end;

        {error, closed} ->
            {ok, list_to_binary(Bs)};
        {error, Reason} ->
            io:fwrite("error"),
            io:fwrite(Reason)
    end.

searchAllTweets(Symbol, Table_List, Word) ->
    Search = string:concat(Symbol, Word),
    io:format("Word to be searched: ~p\n", [Search]),
    [Row_To_Check | Remaining_List ] = Table_List,
    Val3 = lists:nth(2, Row_To_Check),
    Val2 = element(2, Val3),
    Val1 = maps:from_list(Val2),                            
    {ok, CurrentTweets} = maps:find("tweets",Val1),
    io:fwrite("Searching all tweets\n"),
    searchAllTweets(Symbol, Table_List, Word).


sendMessage(Socket, Client_Dictionary, Tweet, Subscribers, UserName) ->
    if
        Subscribers == [] ->
            io:fwrite("\nNo followers!\n");
        % Client_Dictionary == [] ->
        %     io:fwrite("\nAll clients empty!\n");
        true ->
            % io:format("\nAll Clients: ~p~n",[Client_Dictionary]),

            [Client_To_Send | Remaining_List ] = Subscribers,
            io:format("Client to send: ~p\n", [Client_To_Send]),
            io:format("\nRemaining List: ~p~n",[Remaining_List]),
            Client_Socket_Row = ets:lookup(Client_Dictionary,Client_To_Send),
            Val3 = lists:nth(1, Client_Socket_Row),
            Client_Socket = element(2, Val3),
            io:format("\nClient Socket: ~p~n",[Client_Socket]),
            
            ok = gen_tcp:send(Client_Socket, ["New tweet received!\n",",",UserName,":",Tweet]),
            ok = gen_tcp:send(Socket, "Your tweet has been sent"),
            
            sendMessage(Socket, Client_Dictionary, Tweet, Remaining_List, UserName)
    end,
    io:fwrite("Send message!\n").


printMap(Map) ->
    io:fwrite("**************\n"),
    List1 = maps:to_list(Map),
    io:format("~s~n",[tuplelist_to_string(List1)]),
    io:fwrite("**************\n").

tuplelist_to_string(L) ->
    tuplelist_to_string(L,[]).

tuplelist_to_string([],Acc) ->
    lists:flatten(["[",
           string:join(lists:reverse(Acc),","),
           "]"]);
tuplelist_to_string([{X,Y}|Rest],Acc) ->
    S = ["{\"x\":\"",X,"\", \"y\":\"",Y,"\"}"],
    tuplelist_to_string(Rest,[S|Acc]).

conn_loop(Socket) ->
    io:fwrite("Uh Oh, I can sense someone trying to connect to me!\n\n"),
    receive
        {tcp, Socket, Data} ->
            io:fwrite("...."),
            io:fwrite("\n ~p \n", [Data]),
            if 
                Data == <<"register_account">> ->
                    io:fwrite("Client wants to register an account"),
                    ok = gen_tcp:send(Socket, "username"), % RESPOND BACK - YES/NO
                    io:fwrite("is now registered");
                true -> 
                    io:fwrite("TRUTH")
            end,
            conn_loop(Socket);
            
        {tcp_closed, Socket} ->
            io:fwrite("I swear I am not here!"),
            closed
    end.

