#include "WarfareGlobal.as"
#include "AllHashCodes.as"
#include "SeatsCommon.as"
#include "VehicleCommon.as"
#include "VehicleAttachmentCommon.as"
#include "GenericButtonCommon.as"
#include "Hitters.as";

const string wheelsTurnAmountString = "wheelsTurnAmount";
const string engineRPMString = "engine_RPM";
const string engineRPMTargetString = "engine_RPMtarget";
const string engineThrottleString = "engine_throttle";

const u8 turretShowHPSeconds = 8;

void onInit(CBlob@ this)
{
	this.Tag("vehicle");

	s8 weaponRating = 0;

	string blobName = this.getName();
	int blobHash = blobName.getHash();

	switch(blobHash) // weapon rating and length of linear (map) and circled explosion damage
	{
		case _mausturret: // MAUS Shell cannon
		case _t10turret: // T10 Shell cannon
		{
			weaponRating = 3;
			break;
		}
		case _m60turret: // M60 Shell cannon
		{
			weaponRating = 2;
			break;
		}
		case _uh1: // heli
		{
			weaponRating = 1;
			break;
		}
		case _heavygun: // MG
		{
			weaponRating = 1;
			break;
		}
		case _pszh4turret: // smol APC cannon
		{
			weaponRating = 0;
			break;
		}
		case _btrturret: // big APC cannon
		{
			weaponRating = 0;
			break;
		}
	}

	// speedy stuff
	f32 intake;
	switch(blobHash) // backside vulnerability point
	{
		case _maus: // maus
		intake = -50.0f; break;

		case _t10: // T10
		break;
		
		case _m60: // normal tank
		intake = 50.0f; break;

		case _btr82a: // big APC
		intake = 75.0f; break;

		case _pszh4: // smol APC
		intake = 100.0f; break;

		case _techtruck: // truck
		intake = 150.0f; break;

		case _armory :// armory
		intake = 100.0f; break;

		case _motorcycle: // bike!
		intake = 200.0f; break;
	}
	this.set_f32("add_gas_intake", intake);

	this.set_s8(weaponRatingString, weaponRating);

	this.set_f32(engineRPMString, 0.0f);
	this.set_f32(engineThrottleString, 0.0f);

	this.set_f32(wheelsTurnAmountString, 0.0f);

	this.set_u32("show_hp", 0);
}

void onTick(CBlob@ this)
{
	VehicleInfo@ v;
	if (!this.get("VehicleInfo", @v))
	{
		return;
	}

	// wheels
	if (this.getShape().vellen > 0.11f && !this.isAttached())
	{
		UpdateWheels(this);
	}

	// reload
	if (this.hasAttached() && getGameTime() % 2 == 0)
	{
		f32 time_til_fire = Maths::Max((v.fire_time - getGameTime()), 1);
		if (time_til_fire < 2)
		{
			Vehicle_LoadAmmoIfEmpty(this, v);
		}
	}

	// update movement sounds
	f32 velx = Maths::Abs(this.getVelocity().x);

	// ground sound
	if (velx < 0.5f)
	{
		CSprite@ sprite = this.getSprite();
		f32 vol = sprite.getEmitSoundVolume();
		sprite.SetEmitSoundVolume(vol * 0.95f);
		if (vol < 0.05f)
		{
			sprite.SetEmitSoundPaused(true);
			sprite.SetEmitSoundVolume(1.0f);
		}
	}
	else
	{
		if (this.isOnGround() && !v.ground_sound.isEmpty())
		{
			CSprite@ sprite = this.getSprite();
			if ((this.getVelocity().x > 0.01f || this.getVelocity().x < -0.01f) && sprite.getEmitSoundPaused())
			{
				this.getSprite().SetEmitSound(v.ground_sound);
				sprite.SetEmitSoundPaused(false);
			}

			f32 volMod = v.ground_volume;
			f32 pitchMod = v.ground_pitch;

			if (volMod > 0.0f)
			{
				sprite.SetEmitSoundVolume(Maths::Min(velx * 0.667f * volMod, 1.0f));
			}

			if (pitchMod > 0.0f)
			{
				sprite.SetEmitSoundSpeed(Maths::Max(Maths::Min(Maths::Sqrt(0.5f * velx * pitchMod), 1.5f), 0.75f));
			}
		}
		if (!this.isOnGround() && !v.water_sound.isEmpty())
		{
			CSprite@ sprite = this.getSprite();
			if (sprite.getEmitSoundPaused())
			{
				this.getSprite().SetEmitSound(v.water_sound);
				sprite.SetEmitSoundPaused(false);
			}

			f32 volMod = v.water_volume;
			f32 pitchMod = v.water_pitch;

			if (volMod > 0.0f)
			{
				sprite.SetEmitSoundVolume(Maths::Min(velx * 0.565f * volMod, 1.0f));
			}

			if (pitchMod > 0.0f)
			{
				sprite.SetEmitSoundSpeed(Maths::Max(Maths::Min(Maths::Sqrt(0.5f * velx * pitchMod), 1.5f), 0.75f));
			}
		}
	}

	if (this.get_f32("engine_RPMtarget") > this.get_f32("engine_RPM"))
	{
		f32 custom_add = this.get_f32("add_gas_intake");
		u32 gas_intake = 230 + custom_add + XORRandom(70+custom_add/3.5f); // gas flow variance  (needs equation)
		if (this.get_f32("engine_RPM") > 2000) {gas_intake += 100;}
		this.add_f32("engine_RPM", this.get_f32("engine_throttle") * gas_intake); 

		if (XORRandom(100) < 60)
		{
			if (isClient())
			{	
				Vec2f velocity = Vec2f(((this.get_f32("engine_throttle") - 0.453)*143), 0);
				velocity *= this.isFacingLeft() ? 0.25 : -0.25;
				velocity *= this.get_f32("engine_RPM")/3000;
				velocity += Vec2f(0, -0.35) + this.getVelocity()*0.35f;
				//print("ve" + velocity);
				ParticleAnimated("Smoke", this.getPosition() + Vec2f_lengthdir(this.isFacingLeft() ? this.getWidth()/2.2 : -this.getWidth()/2.2, this.getAngleDegrees()), velocity.RotateBy(this.getAngleDegrees()) + getRandomVelocity(0.0f, XORRandom(35) * 0.01f, 360), 45 + float(XORRandom(90)), 0.3f + XORRandom(50) * 0.01f, Maths::Round(7 - Maths::Clamp(this.get_f32("engine_RPM")/1000, 1, 6)) + XORRandom(2), -0.02 - XORRandom(30) * -0.0005f, false );
			}
		}
	}

	// angling
	CSprite@ sprite = this.getSprite();
	if (sprite !is null) 
	{
		bool fl = this.getVelocity().x < -1.0f;
		bool slow_down = Maths::Abs(this.getVelocity().x) < Maths::Abs(this.getOldVelocity().x);

		f32 speed = Maths::Abs(this.getVelocity().x);
		f32 max_speed = v.move_speed/20000;

		f32 max_diff = fl ? 3.0f : -3.0f; // basic value
		if (this.exists("max_angle_diff")) max_diff = (fl ? this.get_f32("max_angle_diff") : -1 * this.get_f32("max_angle_diff"));
		if (slow_down) max_diff *= -1;

		//max_diff *= speed/max_speed;
		max_diff *= 2;

		//if (Maths::Abs(max_diff) > 0.1f)
		{
			sprite.ResetTransform();
			sprite.RotateBy((this.getPosition().x - this.getOldPosition().x)*-max_speed, Vec2f(this.isFacingLeft() ? 6 : -6,0));

			//print("angle " + (this.getPosition().x - this.getOldPosition().x)*-max_speed);
		}
	}
	else if (sprite !is null) sprite.ResetTransform();

	this.sub_f32("engine_RPM", 50 + XORRandom(80)); // more variance

	this.set_f32("engine_RPM", Maths::Clamp(this.get_f32("engine_RPM"), 0.0f, 30000.0f));
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	bool isServer = getNet().isServer();

	/// LOAD AMMO
	if (isServer && cmd == this.getCommandID("load_ammo"))
	{
		VehicleInfo@ v;
		if (!this.get("VehicleInfo", @v))
		{
			return;
		}
		CBlob@ caller = getBlobByNetworkID(params.read_u16());
		if (caller !is null)
		{
			array < CBlob@ > ammos;
			array < string > eligible_ammo_names;

			for (int i = 0; i < v.ammo_types.length(); ++i)
			{
				const string ammo = v.ammo_types[i].ammo_name;
				eligible_ammo_names.push_back(ammo);
			}

			CBlob@ carryObject = caller.getCarriedBlob();
			// if player has item in hand, we only put that item into vehicle's inventory
			if (carryObject !is null && eligible_ammo_names.find(carryObject.getName()) != -1)
			{
				ammos.push_back(carryObject);
			}
			else
			{
				CInventory@ inv = caller.getInventory();

				for (int i = 0; i < v.ammo_types.length(); ++i)
				{
					const string ammo = v.ammo_types[i].ammo_name;

					for (int i = 0; i < inv.getItemsCount(); i++)
					{
						CBlob@ invItem = inv.getItem(i);
						if (invItem.getName() == ammo)
						{
							ammos.push_back(invItem);
						}
					}
				}
			}

			for (int i = 0; i < ammos.length; i++)
			{
				if (!this.server_PutInInventory(ammos[i]))
				{
					caller.server_PutInInventory(ammos[i]);
				}
			}

			RecountAmmo(this, v);
		}
	}
	// SWAP AMMO
	else if (cmd == this.getCommandID("swap_ammo"))
	{
		VehicleInfo@ v;
		if (!this.get("VehicleInfo", @v))
		{
			return;
		}

		swapAmmo(this, v, v.current_ammo_index + 1);

		if(isServer)
			RecountAmmo(this, v);
	}
	else if (!isServer && cmd == this.getCommandID("sync_ammo"))
	{
		VehicleInfo@ v;
		if (!this.get("VehicleInfo", @v))
		{
			return;
		}

		v.current_ammo_index = params.read_u8();
	}
	else if (!isServer && cmd == this.getCommandID("sync_last_fired"))
	{
		VehicleInfo@ v;
		if (!this.get("VehicleInfo", @v))
		{
			return;
		}

		u8 last;
		if (!params.saferead_u8(last)) return;

		v.last_fired_index = last;
	}
	/// PUT IN MAG
	else if (isServer && cmd == this.getCommandID("putin_mag"))
	{
		CBlob@ caller = getBlobByNetworkID(params.read_u16());
		CBlob@ blob = getBlobByNetworkID(params.read_u16());
		if (caller !is null && blob !is null)
		{
			// put what was in mag into inv
			CBlob@ magBlob = getMagBlob(this);
			if (magBlob !is null)
			{
				magBlob.server_DetachFromAll();
			}
			blob.server_DetachFromAll();
			this.server_AttachTo(blob, "MAG");
		}
	}
	/// FIRE
	else if (cmd == this.getCommandID("fire"))
	{
		CBlob@ caller = getBlobByNetworkID(params.read_netid());
		const u8 charge = params.read_u8();
		VehicleInfo@ v;
		if (!this.get("VehicleInfo", @v))
		{
			return;
		}
		Fire(this, v, caller, charge);
		if (isServer)
			RecountAmmo(this, v);
	}
	/// FLIP OVER
	else if (cmd == this.getCommandID("flip_over"))
	{
		if (isFlipped(this))
		{
			this.getShape().SetStatic(false);
			this.getShape().doTickScripts = true;
			f32 angle = this.getAngleDegrees();
			this.AddTorque(angle < 180 ? -1000 : 1000);
			this.AddForce(Vec2f(0, -1000));
		}
	}
	/// GET IN MAG
	else if (isServer && cmd == this.getCommandID("getin_mag"))
	{
		CBlob@ caller = getBlobByNetworkID(params.read_u16());
		if (caller !is null)
			this.server_AttachTo(caller, "MAG");
	}
	/// GET OUT
	else if (isServer && cmd == this.getCommandID("vehicle getout"))
	{
		CBlob@ caller = getBlobByNetworkID(params.read_u16());

		if (caller !is null)
		{
			this.server_DetachFrom(caller);
		}
	}
	/// RELOAD as in server_LoadAmmo   - client-side
	else if (!isServer && cmd == this.getCommandID("reload"))
	{
		u8 loadedAmmo = params.read_u8();

		if (loadedAmmo > 0 && this.getAttachments() !is null)
		{
			SetOccupied(this.getAttachments().getAttachmentPointByName("MAG"), 1);
		}

		VehicleInfo@ v;
		if (!this.get("VehicleInfo", @v))
		{
			return;
		}
		v.getCurrentAmmo().loaded_ammo = loadedAmmo;
	}
	else if (isClient() && cmd == this.getCommandID("recount ammo"))
	{
		VehicleInfo@ v;
		if (!this.get("VehicleInfo", @v))
		{
			return;
		}

		u8 current_recounted = params.read_u8();
		v.ammo_types[current_recounted].ammo_stocked = params.read_u16();
		v.ammo_types[current_recounted].loaded_ammo = params.read_u8();
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	// if damage is not insignificant, prevent repairs for a time
	if (damage > 0.25f)
	{
		this.set_u32("no_heal", getGameTime()+10*30);

		if (isClient())
		{
			CSprite@ thisSprite = this.getSprite();
			if (thisSprite != null && customData == Hitters::ballista && this.get_s8(armorRatingString) > 1) // ballista hits are usually anti-tank. Don't ask me.
			{
				if (this.hasTag("turret")) thisSprite.PlaySound("BigDamage", 2.5f, 0.85f + XORRandom(40)*0.01f); 
				thisSprite.PlaySound("shell_Hit", 3.5f, 0.85f + XORRandom(40)*0.01f);
			}
		}
	}

	return damage;
}

bool isInventoryAccessible(CBlob@ this, CBlob@ forBlob)
{
	if (this.hasTag("turret")) this.set_u32("show_hp", getGameTime() + turretShowHPSeconds * 30);

	if (forBlob.getTeamNum() == this.getTeamNum() && canSeeButtons(this, forBlob))
	{
		VehicleInfo@ v;
		if (!this.get("VehicleInfo", @v))
		{
			return false;
		}
		return v.inventoryAccess;
	}
	return false;
}

// VehicleCommon.as
void Vehicle_onFire(CBlob@ this, VehicleInfo@ v, CBlob@ bullet, const u8 charge) {}
bool Vehicle_canFire(CBlob@ this, VehicleInfo@ v, bool isActionPressed, bool wasActionPressed, u8 &out chargeValue) {return false;}

void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	if (!solid)
	{
		return;
	}

	f32 vellen = this.getShape().vellen;
	// sound
	const f32 soundbase = 1.0;

	if (vellen > soundbase)
	{
		f32 volume = Maths::Min(1.0f, Maths::Max(0.2f, (vellen - soundbase) / soundbase));

		if (vellen > 3.0f)
		{
			this.getSprite().PlayRandomSound("/WoodHeavyBump", volume, 0.9);
		}
		else
		{
			this.getSprite().PlayRandomSound("/WoodHeavyHit", volume, 0.9);
		}
	}

	// damage
	if (!this.hasTag("ignore fall"))
	{
		const f32 base = 5.0f;
		const f32 ramp = 1.2f;

		if (getNet().isServer() && vellen > base) // server only
		{
			if (vellen > base * ramp)
			{
				f32 damage = 0.0f;

				if (vellen < base * Maths::Pow(ramp, 1))
				{
					damage = 0.5f;
				}
				else if (vellen < base * Maths::Pow(ramp, 2))
				{
					damage = 1.0f;
				}
				else if (vellen < base * Maths::Pow(ramp, 3))
				{
					damage = 2.0f;
				}
				else if (vellen < base * Maths::Pow(ramp, 3))
				{
					damage = 3.0f;
				}
				else //very dead
				{
					damage = 10.0f;
				}

				this.server_Hit(this, point1, normal, damage, Hitters::fall);
			}
		}
	}
}