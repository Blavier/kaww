#include "WarfareGlobal.as"
#include "AllHashCodes.as"
#include "Hitters.as";

void onInit(CBlob@ this)
{
	s8 armorRating = 0;
	bool hardShelled = false;

	s8 weaponRating = 0;

	string blobName = this.getName();
	int blobHash = blobName.getHash();
	switch(blobHash)
	{
		case _maus: // maus
		case _mausturret: // MAUS Shell cannon
		{
			armorRating = 5;
			hardShelled = true;
		}
		break;

		case _t10: // T10
		case _t10turret: // T10 Shell cannon
		armorRating = 4; break;
			
		case _m60: // normal tank
		case _m60turret: // M60 Shell cannon
		armorRating = 3; break;

		case _transporttruck: // vanilla truck?
		case _armory: // shop truck
		case _btr82a: // big APC
		case _btrturret: // big APC cannon
		case _heavygun: // MG
		armorRating = 2; break;

		case _uh1: // heli
		case _pszh4: // smol APC
		case _pszh4turret: // smol APC cannon
		case _techtruck: // MG truck
		case _gun: // light MG
		armorRating = 1; break;

		case _bf109: // plane
		case _civcar: // car
		armorRating = 0; break;

		case _motorcycle: // bike
		case _jourcop: // journalist
		armorRating = -1; break;

		default:
		{
			print ("blobName: "+ blobName + " hash: "+blobHash);
			print ("---------------");
		}
	}

	float backsideOffset = -1.0f;
	switch(blobHash) // backside vulnerability point
	{
		case _maus: // maus
		backsideOffset = 20.0f; break;

		case _t10: // T10
		backsideOffset = 20.0f; break;
		
		case _m60: // normal tank
		backsideOffset = 16.0f; break;

		case _btr82a: // big APC
		backsideOffset = 16.0f; break;

		case _pszh4: // smol APC
		backsideOffset = 16.0f; break;

		case _uh1: // heli
		backsideOffset = 24.0f; break;

		case _bf109: // plane
		backsideOffset = 8.0f; break;
	}

	this.set_s8(armorRatingString, armorRating);
	this.set_bool(hardShelledString, hardShelled);

	this.set_f32(backsideOffsetString, backsideOffset);
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	Vec2f thisPos = this.getPosition();
	Vec2f hitterBlobPos = hitterBlob.getPosition();

	s8 armorRating = this.get_s8(armorRatingString);
	s8 penRating = hitterBlob.get_s8(penRatingString);
	bool hardShelled = this.get_bool(hardShelledString);

	if (customData == Hitters::sword) penRating -= 3; // knives don't pierce armor

	const bool is_explosive = customData == Hitters::explosion || customData == Hitters::keg;

	bool isHitUnderside = false;
	bool isHitBackside = false;

	float damageNegation = 0.0f;
	//print ("blob: "+this.getName()+" - damage: "+damage);
	s8 finalRating = getFinalRating(armorRating, penRating, hardShelled, this, hitterBlobPos, isHitUnderside, isHitBackside);
	//print("finalRating: "+finalRating);
	// add more damage if hit from below or hit backside of the tank (only hull)
	if (isHitUnderside || isHitBackside)
	{
		damage *= 1.5f;
	}

	switch (finalRating)
	{
		// negative armor, trickles up
		case -2:
		{
			if (is_explosive && damage != 0) damage += 1.5f; // suffer bonus base damage (you just got your entire vehicle burned)
			damage *= 1.5f;
		}
		case -1:
		{
			damage *= 1.3f;
		}
		break;

		// positive armor, trickles down
		case 5:
		{
			damageNegation += 0.5f; // reduction to final damage, extremely tanky
		}
		case 4:
		{
			damage *= 0.6f;
		}
		case 3:
		{
			damage *= 0.7f;
		}
		case 2:
		{
			damage *= 0.7f;
		}
		case 1:
		{
			damageNegation += 0.2f; // reduction to final damage, for negating small bullets
			damage = Maths::Max(damage - damageNegation, 0.0f); // nullification happens here
		}
		break;
	}

	//print ("finalDamage: "+damage);

	return damage;
}