-module(client).
-export[start/0].

start() ->
    io:fwrite("\n Hello, session established.\n"),
    PortNumber = 1204,
    IPAddress = "localhost",
    {ok, Sock} = gen_tcp:connect(IPAddress, PortNumber, [binary, {packet, 0}]),
    io:fwrite("\n\n Just sent my request to the server\n\n"),
    loop(Sock, "_").

loop(Sock, UserName) ->
    receive
        {tcp, Sock, Data} ->
            io:fwrite(Data),
            % ask user for a command
            % user enters a command 
            UserName1 = input_from_user(Sock, UserName),
            loop(Sock, UserName1);
        {tcp, closed, Sock} ->
            io:fwrite("Client Cant connect anymore - TCP Closed") 
        end.

input_from_user(Sock, UserName) ->
    
    % ask user for a input command
    {ok, [CommandType]} = io:fread("\nEnter the command: ", "~s\n"),
    io:fwrite(CommandType),

    % parse that command - register, subscribe <user_name>
    if 
        CommandType == "register" ->
            UserName1 = register(Sock);
        CommandType == "tweet" ->
            if
                UserName == "_" ->
                    io:fwrite("Please register first!\n"),
                    UserName1 = input_from_user(Sock, UserName);
                true ->
                    send(Sock,UserName),
                    UserName1 = UserName
            end;
        CommandType == "retweet" ->
            if
                UserName == "_" ->
                    io:fwrite("Please register first!\n"),
                    UserName1 = input_from_user(Sock, UserName);
                true ->
                    retweet(Sock, UserName),
                    UserName1 = UserName
            end;
        CommandType == "subscribe" ->
            if
                UserName == "_" ->
                    io:fwrite("Please register first!\n"),
                    UserName1 = input_from_user(Sock, UserName);
                true ->
                    subscribe(Sock, UserName),
                    UserName1 = UserName
            end;
        CommandType == "query" ->
            if
                UserName == "_" ->
                    io:fwrite("Please register first!\n"),
                    UserName1 = input_from_user(Sock, UserName);
                true ->
                    query(Sock, UserName),
                    UserName1 = UserName
            end;
        true ->
            io:fwrite("Invalid command!, Please Enter another command!\n"),
            UserName1 = input_from_user(Sock, UserName)
    end,
    UserName1.


register(Sock) ->

    % Enter the username
    {ok, [UserName]} = io:fread("\nEnter the User Name: ", "~s\n"),
    io:format("SELF: ~p\n", [self()]),
    ok = gen_tcp:send(Sock, [["register", ",", UserName, ",", pid_to_list(self())]]),
    io:fwrite("\nUser has been registered successfully\n"),
    UserName.

send(Sock,UserName) ->
    Tweet = io:get_line("\nWhat would you like to tweet?"),
    ok = gen_tcp:send(Sock, ["tweet", "," ,UserName, ",", Tweet]),
    io:fwrite("\nTweeted\n").

retweet(Socket, UserName) ->
    {ok, [Person_UserName]} = io:fread("\nWhich user's tweet do you want to retweet ", "~s\n"),
    Tweet = io:get_line("\nPlease type the tweet "),
    ok = gen_tcp:send(Socket, ["retweet", "," ,Person_UserName, ",", UserName,",",Tweet]),
    io:fwrite("\nRetweeted\n").

subscribe(Sock, UserName) ->
    SubscribeUserName = io:get_line("\nAnd whom do you want to subscribe?:"),
    ok = gen_tcp:send(Sock, ["subscribe", "," ,UserName, ",", SubscribeUserName]),
    io:fwrite("\nSubscribed!\n").

query(Sock, UserName) ->
    io:fwrite("\n Querying Options:\n"),
    io:fwrite("\n 1. My Mentions\n"),
    io:fwrite("\n 2. Hashtag Search\n"),
    io:fwrite("\n 3. Subscribed Users Tweets\n"),
    {ok, [Option]} = io:fread("\nWhich option would you like to choose ", "~s\n"),
    if
        Option == "1" ->
            ok = gen_tcp:send(Sock, ["query", "," ,UserName, ",", "1"]);
        Option == "2" ->
            Hashtag = io:get_line("\nEnter the hahstag you want to search: "),
            ok = gen_tcp:send(Sock, ["query", "," ,UserName, ",","2",",", Hashtag]);
        true ->
            Sub_UserName = io:get_line("\nWhose tweets do you want? "),
            ok = gen_tcp:send(Sock, ["query", "," ,UserName, ",", "3",",",Sub_UserName])
    end,
    % Query = io:get_line("\nWhat are you looking for? "),
    % ok = gen_tcp:send(Sock, ["query", "," ,UserName, ",", Query]),
    io:fwrite("Queried related tweets").

