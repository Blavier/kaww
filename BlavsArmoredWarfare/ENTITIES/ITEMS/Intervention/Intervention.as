#include "WarfareGlobal.as"
#include "ComputerCommon.as"
#include "OrdnanceCommon.as"

void onInit(CBlob@ this)
{
	this.Tag("medium weight");
	this.Tag("trap"); // so bullets pass
	this.Tag("hidesgunonhold"); // is it's own weapon

	this.Tag("ignore_holding");

	this.addCommandID(launchOrdnanceIDString);
}

void onTick(CBlob@ this)
{
	const bool is_client = isClient();
	const bool is_dead = this.hasTag("dead");

	if (!this.isAttached()) return; // cutoff for performance's sake
	
	AttachmentPoint@ point = this.getAttachments().getAttachmentPointByName("PICKUP");
	if (point is null) return;

	CBlob@ ownerBlob = point.getOccupied();
	if (ownerBlob is null) return;

	if (isServer())
	{
		int ownerTeamNum = ownerBlob.getTeamNum();
		int teamNum = this.getTeamNum();
		if (ownerTeamNum != teamNum) this.server_setTeamNum(ownerBlob.getTeamNum());
	}
	
	const bool isFacingLeft = ownerBlob.isFacingLeft();
	
	Vec2f thisPos = this.getPosition();
	Vec2f ownerPos = ownerBlob.getPosition();
	Vec2f ownerAimpos = ownerBlob.getAimPos() + Vec2f(2.0f, 2.0f);

	Vec2f aimVec = ownerAimpos - thisPos;
	Vec2f aimNorm = aimVec;
	aimNorm.Normalize();

	float aimAngle = -aimNorm.getAngleDegrees() + 360.0f;
	this.setAngleDegrees(isFacingLeft ? aimAngle+180.0f : aimAngle);

	if (!ownerBlob.isMyPlayer() || ownerBlob.isAttached()) return; // only player holding this
	CControls@ controls = getControls();

	Vec2f barrelPos = Vec2f(isFacingLeft ? -4.0f : 4.0f, isFacingLeft ? 2.0f : -2.0f).RotateByDegrees(aimAngle);
	Vec2f updatedPos = thisPos+barrelPos;
	drawParticleLine( updatedPos, updatedPos+(aimNorm*1000.0f), Vec2f_zero, greenConsoleColor, 0, 5.0f); // trajectory

	// binoculars effect
	ownerBlob.set_u32("dont_change_zoom", getGameTime()+3);
	ownerBlob.Tag("binoculars");

	/*
	if (is_dead)
	{
		if (controls.isKeyJustPressed(KEY_KEY_R))
		{
			launcherSetDeath( this, false );
		}
		return;
	}

	CMap@ map = getMap();
	if (map == null) return;

	if (isClient())
	{
		map.rayCastSolid(barrelPos, barrelPos+aimNorm*500.0f, targetPos) && targetPos != Vec2f_zero)
		drawParticleLine( robotechPos, targetBlob.getPosition(), Vec2f_zero, greenConsoleColor, 0, 5.0f); // trajectory
	}


	makeTargetSquare(robotechPos, 0, Vec2f(3.0f, 3.0f), 3.0f, 1.0f, greenConsoleColor); // turnpoint
	
	CBlob@ targetBlob = getBlobByNetworkID(curTargetNetID);
	if (curTargetNetID == 0 || targetBlob == null)
	{
		makeTargetSquare(ownerAimpos, 0, Vec2f(32.0f, 20.0f), 2.0f, 1.0f, greenConsoleColor); // mouse reticle
	}
	else
	{
		drawParticleLine( ownerPos - Vec2f(0,2), robotechPos, Vec2f_zero, greenConsoleColor, 0, 5.0f); // trajectory
		
	}*/

	if (ownerBlob.isKeyJustPressed(key_action1))
	{
		this.SendCommand(this.getCommandID(launchOrdnanceIDString));
	}

	/*
	bool differentAngle = launcherAngle != this.getAngleDegrees();
	bool differentFrame = launcherFrame != this.get_s8("launcher_frame");
	
	if (differentAngle || differentFrame)
	{
		CBitStream params;
		params.write_s8(launcherFrame);
		params.write_f32(launcherAngle);
		this.SendCommand(this.getCommandID(launcherUpdateStateIDString), params);
	}*/
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (this == null) return;

	if (cmd == this.getCommandID(launchOrdnanceIDString))
	{
		if (this.hasTag("dead")) return;

		const bool isFacingLeft = this.isFacingLeft();
		float thisAngle = this.getAngleDegrees();
		if (isFacingLeft) thisAngle - 180.0f;

		Vec2f barrelPos = Vec2f(isFacingLeft ? -4.0f : 4.0f, -2.0f).RotateByDegrees(thisAngle);
		Vec2f launchVec = Vec2f(isFacingLeft ? -1.0f : 1.0f, 0).RotateByDegrees(thisAngle);
		Vec2f thisPos = this.getPosition();

		u16 playerNetID = 0;
		if (this.isAttached())
		{
			AttachmentPoint@ point = this.getAttachments().getAttachmentPointByName("PICKUP");
			if (point is null) return;

			CBlob@ ownerBlob = point.getOccupied();
			if (ownerBlob is null) return;

			ownerBlob.setVelocity(ownerBlob.getVelocity() - (launchVec*5.0f));

			CPlayer@ player = ownerBlob.getPlayer();
			if (player != null) playerNetID = player.getNetworkID();
		}

		if (isServer())
		{
			CBlob@ blob = server_CreateBlob("bulletheavy", this.getTeamNum(), thisPos + barrelPos);
			if (blob != null)
			{
				blob.setVelocity(launchVec*50.0f);
				blob.IgnoreCollisionWhileOverlapped(this);

				if (playerNetID != 0) blob.SetDamageOwnerPlayer(getPlayerByNetworkId(playerNetID));

				blob.set_f32("bullet_damage_body", 10.0f);
				blob.set_f32("bullet_damage_head", 12.0f);
				blob.set_s8(penRatingString, 4);
			}
		}

		//launcherSetDeath(this, true); // set dead
	}
}