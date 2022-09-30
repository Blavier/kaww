// generic ordinance logic

#include "WarfareGlobal.as"
#include "OrdnanceCommon.as"
#include "ComputerCommon.as"

void onInit(CBlob@ this)
{
	this.server_SetTimeToDie(15);
	this.set_s8(navigationPhaseString, 0);

	string thisBlobName = this.getName();
	int thisBlobHash = thisBlobName.getHash();

	float projExplosionRadius = 30.0f;
	float projExplosionDamage = 15.0f;
	s8 penRating = 0;

	MissileInfo missile;
	getMissileStats(thisBlobHash, missile.main_engine_force, missile.turn_speed, missile.max_speed, 
	missile.gravity_scale, projExplosionRadius, projExplosionDamage, penRating);
	this.set("missileInfo", @missile);

	this.getShape().SetGravityScale(missile.gravity_scale);

	this.set_f32(projExplosionRadiusString, projExplosionRadius);
	this.set_f32(projExplosionDamageString, projExplosionDamage);
	this.set_s8(penRatingString, penRating);

	this.set_bool(firstTickString, true);
	this.set_bool(clientFirstTickString, true);

	if (isClient()) this.getSprite().SetFrame(0);

	this.addCommandID( targetUpdateCommandID );
}

void onCommand( CBlob@ this, u8 cmd, CBitStream @params )
{
	if (this == null)
	{ return; }
	
    if (cmd == this.getCommandID(targetUpdateCommandID)) // updates target for all clients
    {
		u16 newTargetNetID;
		bool resetTimer;
		
		if (!params.saferead_u16(newTargetNetID) || !params.saferead_bool(resetTimer)) return;

		this.set_u16(targetNetIDString, newTargetNetID);
		if (resetTimer) this.set_u32(hasTargetTicksString, 0);
	}
}