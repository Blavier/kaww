void onNewPlayerJoin( CRules@ this, CPlayer@ player )
{
	if(isServer() && player != null)
	{
		print("Full join | Player Username = "+ player.getUsername() + " | player IP = "+ player.server_getIP() + " | Player registration time = "+ player.getRegistrationTime());
	}
}