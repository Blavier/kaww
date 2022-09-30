//Missile Include
#include "AllHashCodes.as"

const string launchOrdnanceIDString = "launch_ordnance";
const string launcherSetDeathIDString = "launcher_set_death";
const string launcherUpdateStateIDString = "launcher_state_sync";
const string quickHomingTag = "quick_homing";

Random _ordnance_r(12231);

namespace JavelinParams
{
	// movement general
	const ::f32 MAIN_ENGINE_FORCE = 0.5f;
	const ::f32 secondary_engine_force = 0.1f;
	const ::f32 rcs_force = 0.1f;
	const ::f32 TURN_SPEED = 10.0f; // degrees per tick, 0 = instant (30 ticks a second)
	const ::f32 MAX_SPEED = 10.0f; // 0 = infinite speed

	// factors
	const ::f32 GRAVITY_SCALE = 0.6f;

	//targeting
	const ::u32 lose_target_ticks = 90; //ticks until targetblob is null again

	// damage
	const ::f32 EXPLOSION_RADIUS = 30.0f;
	const ::f32 EXPLOSION_DAMAGE = 15.0f;
	const ::s8 PEN_RATING = 3;
}

namespace GutseekerParams
{
	// movement general
	const ::f32 MAIN_ENGINE_FORCE = 0.7f;
	const ::f32 TURN_SPEED = 20.0f; // degrees per tick, 0 = instant (30 ticks a second)
	const ::f32 MAX_SPEED = 15.0f; // 0 = infinite speed

	// factors
	const ::f32 GRAVITY_SCALE = 0.6f;

	// damage
	const ::f32 EXPLOSION_RADIUS = 30.0f;
	const ::f32 EXPLOSION_DAMAGE = 15.0f;
	const ::s8 PEN_RATING = 1;
}

namespace ShutdownParams
{
	// movement general
	const ::f32 MAIN_ENGINE_FORCE = 0.7f;
	const ::f32 TURN_SPEED = 20.0f; // degrees per tick, 0 = instant (30 ticks a second)
	const ::f32 MAX_SPEED = 15.0f; // 0 = infinite speed

	// factors
	const ::f32 GRAVITY_SCALE = 0.7f;

	// damage
	const ::f32 EXPLOSION_RADIUS = 20.0f;
	const ::f32 EXPLOSION_DAMAGE = 15.0f;
	const ::s8 PEN_RATING = 1;
}

class MissileInfo
{
	// movement general
	f32 main_engine_force;
	f32 secondary_engine_force;
	f32 rcs_force;
	f32 turn_speed; // degrees per tick, 0 = instant (30 ticks a second)
	f32 max_speed; // 0 = infinite speed

	// factors
	f32 gravity_scale;

	//targeting
	u32 lose_target_ticks; //ticks until targetblob is null again
	u16[] target_netid_list; // NetID array

	MissileInfo()
	{
		//movement general
		main_engine_force = 3.0f;
		secondary_engine_force = 2.0f;
		rcs_force = 1.0f;
		turn_speed = 1.0f;
		max_speed = 200.0f;

		// factors
		gravity_scale = 1.0f;

		//targeting
		lose_target_ticks = 30;
	}
};

shared class LauncherInfo
{
	float progress_speed;

	u16[] found_targets_id; // NetID array

	LauncherInfo()
	{
		progress_speed = 0.1f;
	}
};

void launcherSetDeath( CBlob@ this, bool setDead = true )
{
	CBitStream params;
	params.write_bool(setDead);
	this.SendCommand(this.getCommandID(launcherSetDeathIDString), params);
}

void getMissileStats( int blobNameHash, float &out main_engine_force, float &out turn_speed, float &out max_speed, 
	float &out gravity_scale, float &out explosion_radius, float &out explosion_damage, s8 &out pen_rating )
{
	switch(blobNameHash)
	{
		case _missile_gutseeker:
		{
			main_engine_force = GutseekerParams::MAIN_ENGINE_FORCE;
			turn_speed = GutseekerParams::TURN_SPEED;
			max_speed = GutseekerParams::MAX_SPEED;

			gravity_scale = GutseekerParams::GRAVITY_SCALE;

			explosion_radius = GutseekerParams::EXPLOSION_RADIUS;
			explosion_damage = GutseekerParams::EXPLOSION_DAMAGE;
			pen_rating = GutseekerParams::PEN_RATING;
		}
		break;

		case _missile_shutdown:
		{
			main_engine_force = ShutdownParams::MAIN_ENGINE_FORCE;
			turn_speed = ShutdownParams::TURN_SPEED;
			max_speed = ShutdownParams::MAX_SPEED;

			gravity_scale = ShutdownParams::GRAVITY_SCALE;

			explosion_radius = ShutdownParams::EXPLOSION_RADIUS;
			explosion_damage = ShutdownParams::EXPLOSION_DAMAGE;
			pen_rating = ShutdownParams::PEN_RATING;
		}
		break;

		default: // _missile_javelin, but it'll be default stats
		{
			main_engine_force = JavelinParams::MAIN_ENGINE_FORCE;
			turn_speed = JavelinParams::TURN_SPEED;
			max_speed = JavelinParams::MAX_SPEED;

			gravity_scale = JavelinParams::GRAVITY_SCALE;

			explosion_radius = JavelinParams::EXPLOSION_RADIUS;
			explosion_damage = JavelinParams::EXPLOSION_DAMAGE;
			pen_rating = JavelinParams::PEN_RATING;
		}
		break;
	}
}