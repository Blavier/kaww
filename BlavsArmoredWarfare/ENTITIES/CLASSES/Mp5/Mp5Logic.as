#include "ThrowCommon.as";
#include "KnockedCommon.as";
#include "RunnerCommon.as";
#include "ShieldCommon.as";
#include "BombCommon.as";
#include "Hitters.as";
#include "Recoil.as";
#include "InfantryCommon.as";
#include "MedicisCommon.as";
#include "InfantryCommon.as";

void onInit(CBlob@ this)
{
	this.set_u32("mag_bullets_max", 30); // mag size
	this.set_u32("total_ammo", 120); // ???

	this.set_u32("mag_bullets", this.get_u32("mag_bullets_max"));

	ArcherInfo archer;
	this.set("archerInfo", @archer);

	this.Tag("player");
	this.Tag("flesh");
	this.Tag("3x2");
	this.Tag( medicTagString );

	this.addCommandID("sync_reload_to_server");

	this.set_u32("next_ability", getGameTime()+600);

	

	this.set_s8("charge_time", 0);
	this.set_u8("charge_state", ArcherParams::not_aiming);

	this.set_u8("recoil_count", 0);
	this.set_s8("recoil_direction", 0);
	this.set_u8("inaccuracy", 0);

	this.set_bool("has_arrow", false);
	this.set_f32("gib health", -1.5f);

	this.set_Vec2f("inventory offset", Vec2f(0.0f, -80.0f));

	this.getShape().SetRotationsAllowed(false);
	this.addCommandID("shoot bullet");
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;	
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (this.isAttached())
	{
		if (customData == Hitters::explosion)
			return damage*0.05f;
		else if (customData == Hitters::arrow)
			return damage*0.5f;
		else return 0;
	}
	if ((customData == Hitters::explosion || hitterBlob.getName() == "ballista_bolt") && hitterBlob.getName() != "grenade")
	{
		bool at_bunker = false;
		Vec2f pos = this.getPosition();
		Vec2f hit_pos = hitterBlob.getPosition();

		CBlob@[] bunkers;
		getMap().getBlobsInRadius(this.getPosition(), this.getRadius(), @bunkers);

		if (!getMap().rayCastSolidNoBlobs(pos, hit_pos))
		{
			HitInfo@[] infos;
			Vec2f hitvec = hit_pos - pos;

			if (getMap().getHitInfosFromRay(pos, -hitvec.Angle(), hitvec.getLength(), this, @infos))
			{
				for (u16 i = 0; i < infos.length; i++)
				{
					CBlob@ hi = infos[i].blob;
					if (hi is null) continue;
					if (hi.hasTag("bunker") || hi.hasTag("tank")) 
					{
						at_bunker = true;
						break;
					}
				}
			}
			if (at_bunker) return 0;
			return damage * 0.1f;
		}
	}

	return damage;
}

void DoAttack(CBlob@ this, f32 damage, f32 aimangle, f32 arcdegrees, u8 type)
{
	if (!getNet().isServer()) { return; }
	if (aimangle < 0.0f) { aimangle += 360.0f; }

	Vec2f blobPos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f thinghy(1, 0);
	thinghy.RotateBy(aimangle);
	Vec2f pos = blobPos - thinghy * 6.0f + vel + Vec2f(0, -2);
	vel.Normalize();

	f32 attack_distance = 24.0f;

	f32 radius = this.getRadius();
	CMap@ map = this.getMap();
	bool dontHitMore = false;
	bool dontHitMoreMap = false;

	//get the actual aim angle
	f32 exact_aimangle = (this.getAimPos() - blobPos).Angle();

	// this gathers HitInfo objects which contain blob or tile hit information
	HitInfo@[] hitInfos;
	if (map.getHitInfosFromArc(pos, aimangle, arcdegrees, radius + attack_distance, this, @hitInfos))
	{
		//HitInfo objects are sorted, first come closest hits
		for (uint i = 0; i < hitInfos.length; i++)
		{
			HitInfo@ hi = hitInfos[i];
			CBlob@ b = hi.blob;
			if (b !is null && !dontHitMore) // blob
			{
				if (b.hasTag("ignore sword")) continue;

				if (!b.hasTag("flesh")) return;

				//big things block attacks
				const bool large = b.hasTag("blocks sword") && !b.isAttached() && b.isCollidable();

				if (!canHit(this, b))
				{
					// no TK
					if (large)
						dontHitMore = true;

					continue;
				}

				if (!dontHitMore)
				{
					Vec2f velocity = b.getPosition() - pos;
					this.server_Hit(b, hi.hitpos, velocity, damage, type, true); 

					if (b.getPosition().x < this.getPosition().x)
					{
						b.setVelocity(Vec2f(-6.5f, -2.0f));
					}
					else
					{
						b.setVelocity(Vec2f(6.5f, -2.0f));
					}
					
					// end hitting if we hit something solid, don't if its flesh
					if (large)
					{
						dontHitMore = true;
					}
				}
			}
		}
	}
}

void ManageGun(CBlob@ this, ArcherInfo@ archer, RunnerMoveVars@ moveVars)
{
	bool ismyplayer = this.isMyPlayer();
	bool responsible = ismyplayer;
	if (isServer() && !ismyplayer)
	{
		CPlayer@ p = this.getPlayer();
		if (p !is null)
		{
			responsible = p.isBot();
		}
	}

	CControls@ controls = this.getControls();
	CSprite@ sprite = this.getSprite();
	s8 charge_time = this.get_s32("my_chargetime");//archer.charge_time;
	this.set_s8("charge_time", charge_time);
	bool isStabbing = archer.isStabbing;
	bool isReloading = this.get_bool("isReloading"); //archer.isReloading;
	//if (getGameTime()%20==0) printf(""+isReloading);
	u8 charge_state = archer.charge_state;
	bool just_action1;
	bool is_action1;

	just_action1 = (this.get_bool("just_a1") && this.hasTag("can_shoot_if_attached")) || (!this.isAttached() && this.isKeyJustPressed(key_action1) && this.get_u32("dont_change_zoom") < getGameTime()); // binoculars thing
	is_action1 = (this.get_bool("is_a1") && this.hasTag("can_shoot_if_attached")) || (!this.isAttached() && this.isKeyPressed(key_action1));
	bool was_action1 = this.wasKeyPressed(key_action1);
	
	bool hidegun = false;
	if (this.getCarriedBlob() !is null)
	{
		if (this.getCarriedBlob().hasTag("hidesgunonhold"))
		{
			hidegun = true;
		}
	}
	
	const bool pressed_action2 = this.isKeyPressed(key_action2);
	bool menuopen = getHUD().hasButtons();
	Vec2f pos = this.getPosition();

	bool scoped = this.hasTag("scopedin");

	InAirLogic(this);
	
	if (this.get_s8("charge_time") == 46)
	{
		CBitStream params;
		this.SendCommand(this.getCommandID("sync_reload_to_server"), params);
	}

	if (this.isKeyPressed(key_action2))
	{
		this.Untag("scopedin");

		if (!isReloading && !menuopen || this.hasTag("attacking"))
		{
			moveVars.walkFactor *= 0.75f;
			this.Tag("scopedin");
		}
	}
	else
	{
		this.Untag("scopedin");
	}

	if (hidegun) return;

	if (isKnocked(this))
	{
		charge_time = 0;

		archer.isReloading = false;
	}
	else
	{
		// reload
		if (charge_time == 0 && controls !is null && !archer.isReloading && controls.isKeyJustPressed(KEY_KEY_R) && this.get_u32("no_reload") < getGameTime() && this.get_u32("mag_bullets") < this.get_u32("mag_bullets_max"))
		{
			//print("RELOAD!!");
			bool reloadistrue = false;
			CInventory@ inv = this.getInventory();
			if (inv !is null && inv.getItem("mat_7mmround") !is null)
			{
				// actually reloading
				reloadistrue = true;
				charge_time = reloadtime;
				//archer.isReloading = true;
				isReloading = true;
				this.set_bool("isReloading", true);

				CBitStream params; // sync to server
				if (isClient())
				{
					this.getSprite().PlaySound(reloadsfx, 0.8);
					params.write_s8(charge_time);
					this.SendCommand(this.getCommandID("sync_reload_to_server"), params);
				}
			}
			else if (ismyplayer)
			{
				sprite.PlaySound("NoAmmo.ogg", 0.85);
			}

			if (reloadistrue)
			{
				charge_time = reloadtime;
				//archer.isReloading = true;
				this.set_bool("isReloading", true);
			}
		}
		if (isServer() && this.hasTag("sync_reload"))
		{
			s8 reload = charge_time > 0 ? charge_time : this.get_s8("reloadtime");
			if (reload > 0)
			{
				charge_time = reload;
				//archer.isReloading = true;
				this.set_bool("isReloading", true);
				this.Sync("isReloading", true);
				isReloading = true;
				this.Untag("sync_reload");
			}
		}
		// shoot
		if (charge_time == 0 && this.getTickSinceCreated() > 5 && semiauto ? just_action1 : is_action1)
		{
			moveVars.walkFactor *= 0.75f;
			moveVars.jumpFactor *= 0.7f;
			moveVars.canVault = false;

			CPlayer@ player = this.getPlayer();
			if (player !is null)
			{
				//print("p: " + player.getCharacterName() + "  cahrge: " + charge_time);
			}

			if (charge_time == 0 && isStabbing == false)
			{
				if (menuopen) return;
				if (isReloading) return;

				charge_state = ArcherParams::readying;

				if (this.get_u32("mag_bullets") <= 0)
				{
					charge_state = ArcherParams::no_ammo;

					if (ismyplayer && !was_action1)
					{
						sprite.PlaySound("EmptyGun.ogg", 0.4);
					}
				}
				else
				{
					this.AddForce(Vec2f(this.getAimPos() - this.getPosition()) * (this.hasTag("scoped") ? -recoilforce/1.6 : -recoilforce));

					float angle = Maths::ATan2(this.getAimPos().y - this.getPosition().y, this.getAimPos().x - this.getPosition().x) * 180 / 3.14159;
					angle += -0.099f + (XORRandom(2) * 0.01f);

					if (this.isFacingLeft())
					{
						ParticleAnimated("Muzzleflash", this.getPosition() + Vec2f(0.0f, 1.0f), getRandomVelocity(0.0f, XORRandom(3) * 0.01f, this.isFacingLeft()?90:270) + Vec2f(0.0f, -0.05f), angle, 0.06f + XORRandom(3) * 0.01f, 2 + XORRandom(2), -0.15f, false);
					}
					else
					{
						ParticleAnimated("Muzzleflashflip", this.getPosition() + Vec2f(0.0f, 1.0f), getRandomVelocity(0.0f, XORRandom(3) * 0.01f, this.isFacingLeft()?90:270) + Vec2f(0.0f, -0.05f), angle + 180, 0.06f + XORRandom(3) * 0.01f, 2 + XORRandom(2), -0.15f, false);
					}

					ClientFire(this, charge_time);

					charge_time = delayafterfire + XORRandom(randdelay);
					charge_state = ArcherParams::fired;
				}
			}
			else
			{
				charge_time--;

				if (charge_time <= 0)
				{
					charge_time = 0;
					if (isReloading)
					{
						// reload
						CInventory@ inv = this.getInventory();
						if (inv !is null)
						{
							//printf(""+need_ammo);
							//printf(""+current);
							for (u8 i = 0; i < 20; i++)
							{
								u32 current = this.get_u32("mag_bullets");
								u32 max = this.get_u32("mag_bullets_max");
								u32 miss = max-current;
								CBlob@ mag;
								for (u8 i = 0; i < inv.getItemsCount(); i++)
								{
									CBlob@ b = inv.getItem(i);
									if (b is null || b.getName() != "mat_7mmround" || b.hasTag("dead")) continue;
									@mag = @b;
									break;
								}
								if (mag !is null)
								{
									u16 quantity = mag.getQuantity();
									if (quantity <= miss)
									{
										//printf("a");
										//printf(""+miss);
										//printf(""+quantity);
										this.add_u32("mag_bullets", quantity);
										mag.Tag("dead");
										if (isServer()) mag.server_Die();
										continue;
									}
									else
									{
										//printf("e");
										this.set_u32("mag_bullets", max);
										if (isServer()) mag.server_SetQuantity(quantity - miss);
										break;
									}
								}
								else break;
							}
						}
					}
					archer.isStabbing = false;
					archer.isReloading = false;

					this.set_bool("isReloading", false);
				}

			}
		}
		else
		{
			charge_time--;

				if (charge_time <= 0)
				{
					charge_time = 0;
					if (isReloading)
					{
						// reload
						CInventory@ inv = this.getInventory();
						if (inv !is null)
						{
							//printf(""+need_ammo);
							//printf(""+current);
							for (u8 i = 0; i < 20; i++)
							{
								u32 current = this.get_u32("mag_bullets");
								u32 max = this.get_u32("mag_bullets_max");
								u32 miss = max-current;
								CBlob@ mag;
								for (u8 i = 0; i < inv.getItemsCount(); i++)
								{
									CBlob@ b = inv.getItem(i);
									if (b is null || b.getName() != "mat_7mmround" || b.hasTag("dead")) continue;
									@mag = @b;
									break;
								}
								if (mag !is null)
								{
									u16 quantity = mag.getQuantity();
									if (quantity <= miss)
									{
										//printf("a");
										//printf(""+miss);
										//printf(""+quantity);
										this.add_u32("mag_bullets", quantity);
										mag.Tag("dead");
										if (isServer()) mag.server_Die();
										continue;
									}
									else
									{
										//printf("e");
										this.set_u32("mag_bullets", max);
										if (isServer()) mag.server_SetQuantity(quantity - miss);
										break;
									}
								}
								else break;
							}
						}
					}

					archer.isStabbing = false;
					archer.isReloading = false;

					this.set_bool("isReloading", false);
				}

				if (this.getPlayer() !is null)
				{
					bool sprint = this.getHealth() == this.getInitialHealth() && this.isOnGround() && !this.isKeyPressed(key_action2) && (this.getVelocity().x > 1.0f || this.getVelocity().x < -1.0f);
					if (sprint)
					{
						if (!this.hasTag("sprinting"))
						{
							if (isClient())
							{
								ParticleAnimated("DustSmall.png", this.getPosition()-Vec2f(0, -3.75f), Vec2f(this.isFacingLeft() ? 1.0f : -1.0f, -0.1f), 0.0f, 0.75f, 2, XORRandom(70) * -0.00005f, true);
							}
						}
						this.Tag("sprinting");
						moveVars.walkFactor *= 1.0f;
						moveVars.walkSpeedInAir = 2.95f;
						moveVars.jumpFactor *= 1.0f;
					}
					else
					{
						this.Untag("sprinting");
						moveVars.walkFactor *= 0.85f;
						moveVars.walkSpeedInAir = 2.5f;
						moveVars.jumpFactor *= 1.0f;
					}
				}
		}
	}

	// inhibit movement
	if (charge_time > 0)
	{
		if (isReloading)
		{
			this.set_u8("inaccuracy", 0);
			moveVars.walkFactor *= 0.55f;
		}
		if (isStabbing)
		{
			moveVars.walkFactor *= 0.2f;
			moveVars.jumpFactor *= 0.8f;
		}
	}

	if (this.get_u8("hitmarker") > 0)
	{
		this.set_u8("hitmarker", this.get_u8("hitmarker")-1);

		if (this.get_u8("hitmarker") == 20)
		{
			this.set_u8("hitmarker", 0);
		}
	}

	if (this.get_u8("recoil_count") > 0)
	{
		CPlayer@ p = this.getPlayer();
		if (p !is null)
		{
			CBlob@ local = p.getBlob();
			if (local !is null)
			{
				Recoil(this, local, this.get_u8("recoil_count")/3, this.get_s8("recoil_direction"));
			}
		}

		this.set_u8("recoil_count", Maths::Floor(this.get_u8("recoil_count") / lengthofrecoilarc));
	}

	if (this.get_u8("inaccuracy") > 0)
	{
		s8 testnum = (this.get_u8("inaccuracy") - 5);
		if (testnum < 0)
		{
			this.set_u8("inaccuracy", 0);
		}
		else
		{
			this.set_u8("inaccuracy", this.get_u8("inaccuracy") - 5);
		}
		
		if (this.get_u8("inaccuracy") > inaccuracycap) {this.set_u8("inaccuracy", inaccuracycap);}
	}
	
	if (responsible)
	{
		// set cursor
		if (ismyplayer && !getHUD().hasButtons())
		{
			int frame = 0;

			if (this.get_u8("inaccuracy") == 0)
			{
				if (this.isKeyPressed(key_action2))
				{
					getHUD().SetCursorFrame(0);
				}
				else
				{
					getHUD().SetCursorFrame(1);
				}
				
			}
			else
			{
				frame = Maths::Floor(this.get_u8("inaccuracy") / 5);

				if (frame > 9)
				{
					frame = 9;
				}
				if (frame < 1)
				{
					frame = 1;
				}
				getHUD().SetCursorFrame(frame);
			}
		}

		// activate/throw
		//if (this.isKeyJustPressed(key_action3))
		//{
		//	client_SendThrowOrActivateCommand(this);
		//}
	}

	this.set_s32("my_chargetime", charge_time);
	this.Sync("my_chargetime", true);
	archer.charge_state = charge_state;
}

void ManageStab(CBlob@ this, ArcherInfo@ archer)
{
	bool isStabbing = archer.isStabbing;

	// do the stab
	if (archer.charge_time == 10 && archer.isStabbing)
	{
		this.AddForce(Vec2f(this.isFacingLeft() ? -140.0f : 140.0f, -120.0f));

		f32 attackarc = 140.0f;

		DoAttack(this, 0.5f, (this.isFacingLeft() ? 180.0f : 0.0f), attackarc, Hitters::sword);

		Sound::Play("/SwordSlash", this.getPosition());
	}
}

void onTick(CBlob@ this)
{
	ArcherInfo@ archer;
	if (!this.get("archerInfo", @archer))
	{
		return;
	}

	ManageStab(this, archer);

	if (isKnocked(this) || this.isInInventory())
	{
		archer.charge_state = 0;
		archer.charge_time = 0;
		getHUD().SetCursorFrame(0);
		return;
	}

	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	ManageGun(this, archer, moveVars);

	if (!this.isOnGround()) // ladders sometimes dont work
	{
		CBlob@[] blobs;
		getMap().getBlobsInRadius(this.getPosition(), this.getRadius(), blobs);
		for (u16 i = 0; i < blobs.length; i++)
		{
			if (blobs[i] !is null && blobs[i].getName() == "ladder")
			{
				if (this.isOverlapping(blobs[i])) 
				{
					this.getShape().getVars().onladder = true;
					break;
				}
			}
		}
	}
	if (this.isKeyPressed(key_action1)) this.set_u32("no_reload", getGameTime()+10);

	this.set_bool("is_a1", false);
	this.set_bool("just_a1", false);
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}

void ClientFire(CBlob@ this, const s8 charge_time)
{
	if (canSend(this))
	{
		Vec2f targetVector = this.getAimPos() - this.getPosition();
		f32 targetDistance = targetVector.Length();
		f32 targetFactor = targetDistance / 367.0f;

		ShootBullet(this, this.getPosition() - Vec2f(0,2), this.getAimPos() + Vec2f(8, (-this.get_u8("inaccuracy") + XORRandom(this.get_u8("inaccuracy")*2))/1)*targetFactor, 17.59f * bulletvelocity);


		CMap@ map = getMap();
		ParticleAnimated("SmallExplosion3", this.getPosition() + Vec2f(this.isFacingLeft() ? -8.0f : 8.0f, -0.0f), getRandomVelocity(0.0f, XORRandom(40) * 0.01f, this.isFacingLeft() ? 90 : 270) + Vec2f(0.0f, -0.05f), float(XORRandom(360)), 0.6f + XORRandom(50) * 0.01f, 2 + XORRandom(3), XORRandom(70) * -0.00005f, true);
		
		if (this.isMyPlayer()) ShakeScreen2(16, 8, this.getInterpolatedPosition());

		CPlayer@ p = getLocalPlayer();
		if (p !is null)
		{
			CBlob@ local = p.getBlob();
			if (local !is null)
			{
				CPlayer@ ply = local.getPlayer();

				if (ply !is null && ply.isMyPlayer())
				{
					f32 mod = 0.5; // make some smart stuff here?
					if (this.isKeyPressed(key_action2)) mod *= 0.3;

					ShakeScreen((Vec2f(recoilx - XORRandom(recoilx*2) + 1, -recoily + XORRandom(recoily) + 1) * mod), recoillength*mod, this.getInterpolatedPosition());
					ShakeScreen(28*mod, 12*mod, this.getPosition());

					//this.set_s8("recoil_direction", (20 - XORRandom(41)) / sidewaysrecoildamp); // RANDOM SPRAY

					if (!this.isBot())
					{
						this.set_u8("recoil_count", this.isKeyPressed(key_action2) ? recoilcursor*adscushionamount : recoilcursor);               //freq //ampt
						this.set_s8("recoil_direction", ((Maths::Sin(getGameTime()*0.11)/0.059f) + (20 - XORRandom(41))) / sidewaysrecoildamp);
					}

					this.set_u8("inaccuracy", this.get_u8("inaccuracy") + inaccuracypershot * (this.hasTag("sprinting")?2.0f:1.0f));

					makeGibParticle(
					"EmptyShellSmall",	                    // file name
					this.getPosition(),                 // position
					Vec2f(this.isFacingLeft() ? 2.0f : -2.0f, 0.0f), // velocity
					0,                                  // column
					0,                                  // row
					Vec2f(16, 16),                      // frame size
					0.2f,                               // scale?
					0,                                  // ?
					"ShellCasing",                      // sound
					this.get_u8("team_color"));         // team number
				}
			}
		}
	}
}

void ShootBullet(CBlob @this, Vec2f arrowPos, Vec2f aimpos, f32 arrowspeed)
{
	if (canSend(this))
	{
		Vec2f arrowVel = (aimpos - arrowPos);
		arrowVel.Normalize();
		arrowVel *= arrowspeed;
		CBitStream params;
		params.write_Vec2f(arrowPos);
		params.write_Vec2f(arrowVel);

		this.SendCommand(this.getCommandID("shoot bullet"), params);
	}
}

CBlob@ CreateProj(CBlob@ this, Vec2f arrowPos, Vec2f arrowVel)
{
	CBlob@ proj = server_CreateBlobNoInit("bullet");
	if (proj !is null)
	{
		proj.SetDamageOwnerPlayer(this.getPlayer());
		proj.Init();

		proj.set_f32("bullet_damage_body", damage_body);
		proj.set_f32("bullet_damage_head", damage_head);
		proj.IgnoreCollisionWhileOverlapped(this);
		proj.server_setTeamNum(this.getTeamNum());
		proj.setPosition(arrowPos);
		proj.setVelocity(arrowVel);
		proj.getShape().setDrag(proj.getShape().getDrag() * 0.3f);
		proj.setPosition(arrowPos);
	}
	return proj;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("shoot bullet"))
	{
		Vec2f arrowPos;
		if (!params.saferead_Vec2f(arrowPos)) return;
		Vec2f arrowVel;
		if (!params.saferead_Vec2f(arrowVel)) return;
		ArcherInfo@ archer;
		if (!this.get("archerInfo", @archer)) return;

		if (getNet().isServer())
		{
			CBlob@ proj = CreateProj(this, arrowPos, arrowVel);
			proj.server_SetTimeToDie(2.75);
		}

		if (this.get_u32("mag_bullets") > 0) this.set_u32("mag_bullets", this.get_u32("mag_bullets") - 1);
		if (this.get_u32("mag_bullets") > this.get_u32("mag_bullets_max")) this.set_u32("mag_bullets", this.get_u32("mag_bullets_max"));

		this.getSprite().PlaySound(shootsfx, 1.25f, 0.95f + XORRandom(15) * 0.01f);
	}
	else if (cmd == this.getCommandID("sync_reload_to_server"))
	{
		if (isClient())
		{
			//printf(""+this.get_s8("charge_time"));
			if (this.get_bool("isReloading") && (this.get_s8("charge_time") == 46 || this.get_s8("charge_time") == 45))
			{
				makeGibParticle(
				"EmptyMag",               // file name
				this.getPosition() + Vec2f(this.isFacingLeft() ? -3.0f : 3.0f, 2.0f),      // position
				Vec2f(this.isFacingLeft() ? -1.5f : 1.5f, -0.75f),                          // velocity
				0,                                  // column
				0,                                  // row
				Vec2f(16, 16),                      // frame size
				1.0f,                               // scale?
				0,                                  // ?
				"EmptyMagSound",                    // sound
				this.get_u8("team_color"));         // team number
			}
		}
		if (isServer())
		{
			s8 reload = params.read_s8();
			this.set_s8("reloadtime", reload);
			//printf("Synced to server: "+this.get_s8("reloadtime"));
			this.Tag("sync_reload");
			this.Sync("isReloading", true);
		}
	}
}

bool canHit(CBlob@ this, CBlob@ b)
{
	if (b.hasTag("invincible"))
		return false;

	// Don't hit temp blobs and items carried by teammates.
	if (b.isAttached())
	{
		CBlob@ carrier = b.getCarriedBlob();

		if (carrier !is null)
			if (carrier.hasTag("player")
			        && (this.getTeamNum() == carrier.getTeamNum() || b.hasTag("temp blob")))
				return false;
	}

	if (b.hasTag("dead"))
		return true;

	return b.getTeamNum() != this.getTeamNum();
}