#include "Hitters.as";

void onInit(CBlob@ this)
{
	this.set_TileType("background tile", CMap::tile_castle_back);
	this.Tag("builder always hit");
	this.Tag("bunker");

	this.getShape().getConsts().mapCollisions = false;

	this.SetFacingLeft(this.getTeamNum() == 1);
}

void onTick(CBlob@ this)
{
	if (isServer() && this.getTickSinceCreated() == 180 && getGameTime() <= 210)
	{
		CMap@ map = this.getMap();
		if (map !is null)
		{//dont rotate it depending on side after constructing map
			this.server_setTeamNum(this.getPosition().x > map.tilemapwidth*4 ? 1 : 0);
			this.SetFacingLeft(this.getPosition().x > map.tilemapwidth*4);
		}
	}
}

void onDie(CBlob@ this)
{
	if (!isServer())
		return;
	server_CreateBlob("constructionyard",this.getTeamNum(),this.getPosition());
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	if (!blob.isCollidable() || blob.isAttached() || blob.getTeamNum() == this.getTeamNum()) // no colliding against people inside vehicles
		return false;
	if (blob.getRadius() > this.getRadius() ||
	        (blob.getTeamNum() != this.getTeamNum() && blob.hasTag("player") && this.getShape().vellen > 1.0f) ||
	        (blob.getShape().isStatic()) || blob.hasTag("projectile"))
	{
		return true;
	}
	return false;
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (hitterBlob.getName() == "grenade")
	{
		return damage * 3;
	}
	if (customData == Hitters::flying || customData == Hitters::flying)
	{
		this.server_Hit(hitterBlob, hitterBlob.getPosition(), this.getOldVelocity(), 3.5f, Hitters::flying, true);
		if (!hitterBlob.hasTag("deal_bunker_dmg")) return 0;
		return damage / 35;
	}
	if (customData == Hitters::arrow)
	{
		//this.server_Hit(hitterBlob, hitterBlob.getPosition(), this.getOldVelocity(), 3.5f, Hitters::flying, true);

		return damage * 1.5;
	}
	if (customData == Hitters::explosion)
	{
		return damage / 5;
	}
	if (hitterBlob.hasTag("vehicle") && customData != Hitters::explosion)
	{
		if (!hitterBlob.hasTag("deal_bunker_dmg")) return 0;
		return Maths::Min(0.2f, damage);
	}
	
	return damage;
}