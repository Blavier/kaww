#include "WarfareGlobal.as"
#include "ComputerCommon.as"
#include "Hitters.as";
#include "Explosion.as";

const Vec2f upVelo = Vec2f(0.00f, -0.015f);
const Vec2f downVelo = Vec2f(0.00f, 0.0050f);
const Vec2f leftVelo = Vec2f(-0.0275f, 0.00f);
const Vec2f rightVelo = Vec2f(0.0275f, 0.00f);

const Vec2f minClampVelocity = Vec2f(-0.40f, -0.70f);
const Vec2f maxClampVelocity = Vec2f( 0.40f, 0.00f);

const f32 thrust = 1020.00f;

const u8 cooldown_time = 15;//210;
const u8 recoil = 0;

const s16 init_gunoffset_angle = -3; // up by so many degrees

// 0 == up, 90 == sideways
const f32 high_angle = 85.0f; // upper depression limit
const f32 low_angle = 115.0f; // lower depression limit

void onInit(CBlob@ this)
{
	this.set_bool("map_damage_raycast", true);
	this.set_u32("duration", 0);
	//this.getSprite().SetRelativeZ(-60.0f);

	this.Tag("vehicle");
	this.Tag("aerial");
	this.set_bool("lastTurn", false);
	this.set_bool("music", false);
	this.set_bool("glide", false);

	this.addCommandID("shoot bullet");

	if (this !is null)
	{
		CShape@ shape = this.getShape();
		if (shape !is null)
		{
			shape.SetRotationsAllowed(false);
		}
	}

	AttachmentPoint@[] aps;
	if (this.getAttachmentPoints(@aps))
	{
		for (uint i = 0; i < aps.length; i++)
		{
			AttachmentPoint@ ap = aps[i];
			ap.offsetZ = 10.0f;
			ap.SetKeysToTake(key_action1 | key_action2 | key_action3);
		}
	}

	CSprite@ sprite = this.getSprite();
	

	this.SetMapEdgeFlags(CBlob::map_collide_left | CBlob::map_collide_right);

	CBlob@ bow = server_CreateBlob("heavygun");	

	if (bow !is null)
	{
		bow.server_setTeamNum(this.getTeamNum());
		this.server_AttachTo( bow, "BOW" );
		this.set_u16("bowid", bow.getNetworkID());
		bow.SetFacingLeft(this.isFacingLeft());
	}

	this.inventoryButtonPos = Vec2f(-8.0f, 0);
}

void onInit(CSprite@ this)
{	
	this.SetRelativeZ(-20.0f);
	//Add blade
	CSpriteLayer@ blade = this.addSpriteLayer("blade", "UH_Blade.png", 92, 8);
	if (blade !is null)
	{
		Animation@ anim = blade.addAnimation("default", 1, true);
		int[] frames = {1, 2, 3, 2};
		anim.AddFrames(frames);
		
		blade.SetOffset(Vec2f(-5, -26));
		blade.SetRelativeZ(20.0f);
		blade.SetVisible(true);
	}

	//Add tail rotor
	CSpriteLayer@ tailrotor = this.addSpriteLayer("tailrotor", "UH_TailRotor.png", 16, 16);
	if (tailrotor !is null)
	{
		Animation@ anim = tailrotor.addAnimation("default", 1, true);
		int[] frames = {0, 1, 2, 3};
		anim.AddFrames(frames);
		
		tailrotor.SetOffset(Vec2f(58.0, -9));
		tailrotor.SetRelativeZ(20.0f);
		tailrotor.SetVisible(true);
	}

	//Add missile launcher
	CSpriteLayer@ arm = this.addSpriteLayer("arm", "UHT_Launcher", 16, 16);
	if (arm !is null)
	{
		CSpriteLayer@ arm = this.getSpriteLayer("arm");
		if (arm !is null)
		{
			arm.SetRelativeZ(0.5f);
			arm.SetOffset(Vec2f(-32.0f, 10.0f));
		}
	}

	this.SetEmitSound("Eurokopter_Loop.ogg");
	this.SetEmitSoundSpeed(0.01f);
	this.SetEmitSoundPaused(false);
}

void updateLayer(CSprite@ sprite, string name, int index, bool visible, bool remove)
{
	if (sprite !is null)
	{
		CSpriteLayer@ layer = sprite.getSpriteLayer(name);
		if (layer !is null)
		{
			if (remove == true)
			{
				sprite.RemoveSpriteLayer(name);
				return;
			}
			else
			{
				layer.SetFrameIndex(index);
				layer.SetVisible(visible);
			}
		}
	}
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}

void onTick(CBlob@ this)
{	
	Vec2f thisPos = this.getPosition();
	Vec2f thisVel = this.getVelocity();
	if (getGameTime() >= this.get_u32("next_shoot"))
	{
		this.Untag("no_more_shooting");
		this.Untag("no_more_proj");
	}
	if (thisVel.x > 6.25f || thisVel.x < -6.25f) this.setVelocity(Vec2f(this.getOldVelocity().x, this.getVelocity().y));

	if (thisPos.y < 70.0f && thisVel.y < 0.5f)
	{
		//this.setVelocity(Vec2f(thisVel.x, thisVel.y*0.16f));
		this.AddForce(Vec2f(0, 220.0f));
	}

	CSprite@ sprite = this.getSprite();
	CShape@ shape = this.getShape();
	Vec2f currentVel = thisVel;
	f32 angle = shape.getAngleDegrees();

	const bool flip = this.isFacingLeft();

	Vec2f newForce = Vec2f(0, 0);

	AttachmentPoint@[] aps;
	this.getAttachmentPoints(@aps);
	
	CSpriteLayer@ blade = sprite.getSpriteLayer("blade");
	CSpriteLayer@ tailrotor = sprite.getSpriteLayer("tailrotor");
	CSpriteLayer@ arm = sprite.getSpriteLayer("arm");
	for(int a = 0; a < aps.length; a++)
	{
		AttachmentPoint@ ap = aps[a];
		if (ap !is null)
		{
			CBlob@ hooman = ap.getOccupied();
			if (hooman == null) continue;
			
			if (ap.name == "DRIVER")
			{
				const bool pressed_w  = ap.isKeyPressed(key_up);
				const bool pressed_s  = ap.isKeyPressed(key_down);
				const bool pressed_a  = ap.isKeyPressed(key_left);
				const bool pressed_d  = ap.isKeyPressed(key_right);
				const bool pressed_c  = ap.isKeyPressed(key_pickup);
				const bool pressed_m1 = ap.isKeyPressed(key_action1);
				const bool pressed_m2 = ap.isKeyPressed(key_action2);

				if (isClient())
				{
					float rot = flip ? -1.0f : 1.0f;
					Vec2f barrelPos = thisPos + Vec2f(28.0f*rot, 10.0f).RotateBy(angle);
					Vec2f ownerAimpos = ap.getAimPos() + Vec2f(2.0f, 2.0f);
					Vec2f aimVec = ownerAimpos - barrelPos;
					Vec2f aimNorm = aimVec;
					aimNorm.Normalize();

					if (arm != null)
					{
						float aimAngle = -aimNorm.getAngleDegrees() + 360.0f;
						if (flip) aimAngle -= 180.0f;
						arm.ResetTransform();
						arm.RotateByDegrees(aimAngle, Vec2f(4.0f,0));
					}

					// shoot
					if (hooman.isMyPlayer())
					{
						Vec2f targetPos = Vec2f_zero;

						if (getMap().rayCastSolidNoBlobs(barrelPos, barrelPos+aimNorm*500.0f, targetPos) && targetPos != Vec2f_zero)
						{
							drawParticleLine( barrelPos, targetPos, Vec2f_zero, greenConsoleColor, 0, 2.0f); // target line
							makeTargetSquare(targetPos, 0, Vec2f(2.0f, 2.0f), 2.0f, 1.0f, greenConsoleColor); // target pos

							if (!this.hasTag("no_more_shooting") && ap.isKeyPressed(key_action3) && this.get_u32("next_shoot") < getGameTime())
							{
								CInventory@ inv = this.getInventory();
								if (inv !is null && inv.getItem(0) !is null && inv.getItem(0).getName() == "mat_heatwarhead")
								{
									if (!this.hasTag("no_more_shooting")) this.getSprite().PlaySound("Missile_Launch.ogg", 1.25f, 0.95f + XORRandom(15) * 0.01f);
									
									ShootBullet(this, barrelPos, (aimNorm*3.0f) + thisVel, targetPos);
									this.Tag("no_more_shooting");
								}
							}
						}
					}
				}
				
				const f32 mass = this.getMass();

				if (pressed_a) newForce += leftVelo;
				if (pressed_d) newForce += rightVelo;
					
				if (pressed_m1)this.set_bool("glide", true);
				else
				{
					this.set_bool("glide", false);
					if (pressed_w) newForce += upVelo;
					if (pressed_s) newForce += downVelo;
				}

				Vec2f mousePos = ap.getAimPos();
				CBlob@ pilot = ap.getBlob();
				
				if (pilot !is null && pressed_m2 && (this.getVelocity().x < 5.00f || this.getVelocity().x > -5.00f))
				{
					if (mousePos.x < pilot.getPosition().x) this.SetFacingLeft(true);
					else if (mousePos.x > pilot.getPosition().x) this.SetFacingLeft(false);
				}
				else if (this.getVelocity().x < -0.50f)
					this.SetFacingLeft(true);
				else if (this.getVelocity().x > 0.50f)
					this.SetFacingLeft(false);
			}
			
		}
	}
	Vec2f targetForce;
	Vec2f currentForce = this.get_Vec2f("current_force");
	CBlob@ pilot = this.getAttachmentPoint(0).getOccupied();
	if (pilot !is null) targetForce = this.get_Vec2f("target_force") + newForce;
	else targetForce = Vec2f(0, 0);

	f32 targetForce_y = Maths::Clamp(targetForce.y, minClampVelocity.y, maxClampVelocity.y);

	Vec2f clampedTargetForce = Vec2f(Maths::Clamp(targetForce.x, Maths::Max(minClampVelocity.x, -Maths::Abs(targetForce_y)), Maths::Min(maxClampVelocity.x, Maths::Abs(targetForce_y))), targetForce_y);
	
	Vec2f resultForce;
	if(!this.get_bool("glide"))
	{
		resultForce = Vec2f(Lerp(currentForce.x, clampedTargetForce.x, lerp_speed_x), Lerp(currentForce.y, clampedTargetForce.y, lerp_speed_y));
		this.set_Vec2f("current_force", resultForce);
	}
	else
	{
		resultForce = Vec2f(Lerp(currentForce.x, clampedTargetForce.x, lerp_speed_x), -0.5890000005);
		this.set_Vec2f("current_force", resultForce);
	}

	this.AddForce(resultForce * thrust);
	this.setAngleDegrees(resultForce.x * 75.00f);
	
	int anim_time_formula = Maths::Floor(1.00f + (1.00f - Maths::Abs(resultForce.getLength())) * 3) % 4;
	blade.ResetTransform();
	blade.SetOffset(Vec2f(-4, -26));
	blade.animation.time = anim_time_formula;
	if (blade.animation.time == 0)
	{
		blade.SetOffset(Vec2f(-5, -26));
		blade.SetFrameIndex(0);
		blade.RotateBy(180, Vec2f(0.0f,2.0f));
	}
	
	tailrotor.animation.time = anim_time_formula;
	if (tailrotor.animation.time == 0)
	{
		tailrotor.SetFrameIndex(1);
	}
	
	sprite.SetEmitSoundSpeed(Maths::Min(0.00005f + Maths::Abs(resultForce.getLength() * 1.00f), 0.85f) * 1.55);

	this.set_Vec2f("target_force", clampedTargetForce);
	
}

void ShootBullet(CBlob @this, Vec2f arrowPos, Vec2f arrowVel, Vec2f targetPos)
{
	CBitStream params;
	params.write_Vec2f(arrowPos);
	params.write_Vec2f(arrowVel);
	params.write_Vec2f(targetPos);

	this.SendCommand(this.getCommandID("shoot bullet"), params);
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("shoot bullet"))
	{
		this.set_u32("next_shoot", getGameTime()+15);
		Vec2f arrowPos;
		if (!params.saferead_Vec2f(arrowPos)) return;
		Vec2f arrowVel;
		if (!params.saferead_Vec2f(arrowVel)) return;
		Vec2f targetPos;
		if (!params.saferead_Vec2f(targetPos)) return;

		if (getNet().isServer() && !this.hasTag("no_more_proj"))
		{
			CBlob@ proj = CreateProj(this, arrowPos, arrowVel);
			
			proj.set_Vec2f("shutdown_pos", targetPos);

			CInventory@ inv = this.getInventory();
			if (inv !is null && inv.getItem(0) !is null && inv.getItem(0).getName() == "mat_heatwarhead")
			{
				inv.getItem(0).server_SetQuantity(inv.getItem(0).getQuantity()-1);
			}
		} 
	}
}

bool isInventoryAccessible(CBlob@ this, CBlob@ forBlob)
{
	return this.getTeamNum() == forBlob.getTeamNum();
}

CBlob@ CreateProj(CBlob@ this, Vec2f arrowPos, Vec2f arrowVel)
{
	if (!this.hasTag("no_more_proj"))
	{
		CBlob@ proj = server_CreateBlobNoInit("missile_shutdown");
		if (proj !is null)
		{
			proj.SetDamageOwnerPlayer(this.getPlayer());
			proj.Init();

			proj.IgnoreCollisionWhileOverlapped(this);
			proj.server_setTeamNum(this.getTeamNum());
			proj.setVelocity(arrowVel);
			proj.setPosition(arrowPos);
		}
		this.Tag("no_more_proj");
		return proj;
	}
	else
		return null;
}

const f32 lerp_speed_x = 0.20f;
const f32 lerp_speed_y = 0.20f;

f32 Lerp(f32 a, f32 b, f32 time)
{
	return a + (b - a) * time;
}

f32 constrainAngle(f32 x)
{
	x = (x + 180) % 360;
	if (x < 0) x += 360;
	return x - 180;
}

void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint @attachedPoint)
{
	if (attachedPoint.socket)
	{
		this.Tag("no barrier pass");
	}
	if (attached !is null)
	{
		if (attached.hasTag("player") && attached.getTeamNum() != this.getTeamNum())
		{
			this.server_setTeamNum(attached.getTeamNum());
		}
		
		if (attached.getName() != "donotspawnthiswithacommand")
		{
			attached.Tag("invincible");
			attached.Tag("invincibilityByVehicle");
		}
	}
}

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint @attachedPoint)
{
	if (attachedPoint.socket)
	{
		detached.setVelocity(this.getVelocity());
		detached.AddForce(Vec2f(0.0f, -300.0f));
		this.Untag("no barrier pass");
	}
	if (detached !is null)
	{
		detached.Untag("invincible");
		detached.Untag("invincibilityByVehicle");
	}
}

bool doesCollideWithBlob( CBlob@ this, CBlob@ blob )
{
	if (!blob.isCollidable() || blob.isAttached()){
		return false;
	} // no colliding against people inside vehicles
	if (blob.getRadius() > this.getRadius() ||
	        (blob.getTeamNum() != this.getTeamNum() && blob.hasTag("player") && this.getShape().vellen > 1.0f) ||
	        (blob.getShape().isStatic()) || blob.hasTag("projectile"))
	{
		return true;
	}
	return false;
}

void onRender(CSprite@ this)
{
	if (this is null) return; //can happen with bad reload

	// draw only for local player
	CBlob@ blob = this.getBlob();
	CBlob@ localBlob = getLocalPlayerBlob();

	if (blob is null)
	{
		return;
	}

	if (localBlob is null)
	{
		return;
	}
}

void MakeParticle(CBlob@ this, const Vec2f vel, const string filename = "SmallSteam")
{
	if (!isClient()) return;

	Vec2f offset = Vec2f(8, 0).RotateBy(this.getAngleDegrees());
	ParticleAnimated(filename, this.getPosition() + offset, vel, float(XORRandom(360)), 1.0f, 2 + XORRandom(3), -0.1f, false);
}

void onDie(CBlob@ this)
{
	DoExplosion(this);
	
	if (this.exists("bladeid"))
	{
		CBlob@ blade = getBlobByNetworkID(this.get_u16("bladeid"));
		if (blade !is null)
		{
			blade.server_Die();
		}
	}
	if (this.exists("bowid"))
	{
		CBlob@ bow = getBlobByNetworkID(this.get_u16("bowid"));
		if (bow !is null)
		{
			bow.server_Die();
		}
	}
}

string[] particles = 
{
	"LargeSmoke",
	"Explosion.png"
};

void DoExplosion(CBlob@ this)
{
	CRules@ rules = getRules();

	this.set_f32("map_damage_radius", 48.0f);
	this.set_f32("map_damage_ratio", 0.4f);
	f32 angle = this.get_f32("bomb angle");

	Explode(this, 100.0f, 50.0f);

	for (int i = 0; i < 4; i++) 
	{
		Vec2f dir = getRandomVelocity(angle, 1, 40);
		LinearExplosion(this, dir, 40.0f + XORRandom(64), 48.0f, 6, 0.5f, Hitters::explosion);
	}

	Vec2f pos = this.getPosition() + this.get_Vec2f("explosion_offset").RotateBy(this.getAngleDegrees());
	CMap@ map = getMap();

	if (isClient())
	{
		for (int i = 0; i < 40; i++)
		{
			MakeParticle(this, Vec2f( XORRandom(64) - 32, XORRandom(80) - 60), getRandomVelocity(angle, XORRandom(400) * 0.01f, 70), particles[XORRandom(particles.length)]);
		}
	}

	this.getSprite().Gib();
}

void MakeParticle(CBlob@ this, const Vec2f pos, const Vec2f vel, const string filename = "SmallSteam")
{
	if (!isClient()) return;

	ParticleAnimated(filename, this.getPosition() + pos, vel, float(XORRandom(360)), 1 + XORRandom(200) * 0.01f, 2 + XORRandom(5), XORRandom(100) * -0.00005f, true);
}