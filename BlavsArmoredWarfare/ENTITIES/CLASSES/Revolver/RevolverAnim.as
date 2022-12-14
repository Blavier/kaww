#include "InfantryCommon.as"
#include "RunnerAnimCommon.as";
#include "RunnerCommon.as";
#include "KnockedCommon.as";
#include "PixelOffsets.as"
#include "RunnerTextures.as"

const f32 config_offset = -4.0f;

void onInit(CSprite@ this)
{
	LoadSprites(this);
}

void onPlayerInfoChanged(CSprite@ this)
{
	LoadSprites(this);
}

void LoadSprites(CSprite@ this)
{
	ensureCorrectRunnerTexture(this, "revolver", "Revolver");
	string texname = getRunnerTextureName(this);

	// add blade
	this.RemoveSpriteLayer("chop");
	CSpriteLayer@ chop = this.addTexturedSpriteLayer("chop", "Revolver", 32, 32);

	if (chop !is null)
	{
		Animation@ anim = chop.addAnimation("default", 0, true);
		anim.AddFrame(0);
		anim.AddFrame(1);
		anim.AddFrame(2);
		chop.SetVisible(false);
		chop.SetRelativeZ(1000.0f);
	}

	this.RemoveSpriteLayer("frontarm");
	CSpriteLayer@ frontarm = this.addTexturedSpriteLayer("frontarm", texname , 32, 16);

	if (frontarm !is null)
	{
		Animation@ animcharge = frontarm.addAnimation("default", 0, false);
		animcharge.AddFrame(40);
		Animation@ animshoot = frontarm.addAnimation("fired", 0, false);
		animshoot.AddFrame(32);
		Animation@ animnoarrow = frontarm.addAnimation("no_arrow", 0, false);
		animnoarrow.AddFrame(40);
		frontarm.SetOffset(Vec2f(-1.0f, 5.0f + config_offset));
		frontarm.SetAnimation("fired");
		frontarm.SetVisible(false);
	}

	this.RemoveSpriteLayer("backarm");
	CSpriteLayer@ backarm = this.addTexturedSpriteLayer("backarm", texname , 32, 16);

	if (backarm !is null)
	{
		Animation@ anim = backarm.addAnimation("default", 0, false);
		anim.AddFrame(131); //131
		backarm.SetOffset(Vec2f(-10.0f, 5.0f + config_offset));
		backarm.SetAnimation("default");
		backarm.SetVisible(false);
	}
}

void setArmValues(CSpriteLayer@ arm, bool visible, f32 angle, f32 relativeZ, string anim, Vec2f around, Vec2f offset)
{
	if (arm !is null)
	{
		arm.SetVisible(visible);

		if (visible)
		{
			if (!arm.isAnimation(anim))
			{
				arm.SetAnimation(anim);
			}

			arm.SetOffset(offset);
			arm.ResetTransform();
			arm.SetRelativeZ(relativeZ);
			arm.RotateBy(angle, around);
		}
	}
}

void onTick(CSprite@ this)
{
	// store some vars for ease and speed
	CBlob@ blob = this.getBlob();

	if (blob.hasTag("dead"))
	{
		if (this.animation.name != "dead")
		{
			this.SetAnimation("dead");
			this.RemoveSpriteLayer("frontarm");
			this.RemoveSpriteLayer("backarm");
		}

		Vec2f vel = blob.getVelocity();

		if (vel.y < -1.0f)
		{
			this.SetFrameIndex(0);
		}
		else if (vel.y > 1.0f)
		{
			this.SetFrameIndex(1);
		}
		else
		{
			this.SetFrameIndex(2);
		}

		CSpriteLayer@ chop = this.getSpriteLayer("chop");

		if (chop !is null)
		{
			chop.SetVisible(false);
		}

		return;
	}

	ArcherInfo@ archer;
	if (!blob.get("archerInfo", @archer))
	{
		return;
	}

	// animations
	const bool firing = IsFiring(blob);
	bool showgun = true;
	const bool left = blob.isKeyPressed(key_left);
	const bool right = blob.isKeyPressed(key_right);
	const bool up = blob.isKeyPressed(key_up);
	const bool down = blob.isKeyPressed(key_down);
	const bool inair = (!blob.isOnGround() && !blob.isOnLadder());
	bool isStabbing = getGameTime() < blob.get_u32("end_stabbing");
	bool isReloading = blob.get_bool("isReloading"); // archer.isReloading;
	bool crouch = false;

	if (blob.isOnGround())
	{
		if (blob.getVelocity().x <= 1.0f && blob.getVelocity().x >= -1.0f)
		{
			if (down)
			{
				this.ResetTransform();
				this.SetOffset(Vec2f(0, -2.5));
			}
			else this.SetOffset(Vec2f(0, -4.0));
		}
		else this.SetOffset(Vec2f(0, -4.0));
	}

	bool knocked = isKnocked(blob) && !isReloading;
	Vec2f pos = blob.getPosition();
	Vec2f aimpos = blob.getAimPos();
	// get the angle of aiming with mouse
	Vec2f vec = aimpos - pos;
	f32 angle = vec.Angle();

	bool wantsChopLayer = false;
	s32 chopframe = 0;
	f32 chopAngle = 0.0f;

	if (!blob.hasTag("show_gun") && (isStabbing || isReloading || blob.isAttached()))
	{
		showgun = false;
	}

	if (knocked)
	{
		if (inair)
		{
			this.SetAnimation("knocked_air");
		}
		else
		{
			this.SetAnimation("knocked");
		}
	}
	else if (blob.hasTag("seated"))
	{
		this.SetAnimation("default");
	}
	else if (blob.hasTag("seatez"))
	{
		this.SetAnimation("heavy");
	}
	else if (showgun)
	{
		if (inair)
		{
			this.SetAnimation("shoot_jump");
		}
		else if ((left || right) ||
		         (blob.isOnLadder() && (up || down)))
		{
			if (blob.hasTag("sprinting"))
			{
				this.SetAnimation("sprint");
			}
			else
			{
				if (blob.isKeyPressed(key_action2))
				{
					this.SetAnimation("shoot_walk");
				}
				else
				{
					this.SetAnimation("shoot_run");
				}
			}
		}
		else
		{
			this.SetAnimation("shoot");
		}
	}
	else if (isStabbing)
	{
		this.SetAnimation("stab");
	}
	else if (isReloading)
	{
		this.SetAnimation("reload");
	}
	else if (inair)
	{
		RunnerMoveVars@ moveVars;
		if (!blob.get("moveVars", @moveVars))
		{
			return;
		}
		Vec2f vel = blob.getVelocity();
		f32 vy = vel.y;
		if (vy < -0.0f && moveVars.walljumped)
		{
			this.SetAnimation("run");
		}
		else
		{
			this.SetAnimation("fall");
			this.animation.timer = 0;

			if (vy < -1.5)
			{
				this.animation.frame = 0;
			}
			else if (vy > 1.5)
			{
				this.animation.frame = 2;
			}
			else
			{
				this.animation.frame = 1;
			}
		}
	}
	else if ((left || right) ||
	         (blob.isOnLadder() && (up || down)))
	{
		this.SetAnimation("run");
	}
	else
	{
		if (down && this.isAnimationEnded())
			crouch = true;

		int direction;

		if ((angle > 330 && angle < 361) || (angle > -1 && angle < 30) ||
		        (angle > 150 && angle < 210))
		{
			direction = 0;
		}
		else if (aimpos.y < pos.y)
		{
			direction = -1;
		}
		else
		{
			direction = 1;
		}

		defaultIdleAnim(this, blob, direction);
	}

	CSpriteLayer@ chop = this.getSpriteLayer("chop");

	if (chop !is null)
	{
		chop.SetVisible(false); //wantsChopLayer
		if (wantsChopLayer)
		{
			f32 choplength = 5.0f;

			chop.animation.frame = chopframe;
			Vec2f offset = Vec2f(choplength, 0.0f);
			offset.RotateBy(chopAngle, Vec2f_zero);
			if (!this.isFacingLeft())
				offset.x *= -1.0f;
			offset.y += this.getOffset().y * 0.5f;

			chop.SetOffset(offset);
			chop.ResetTransform();
			if (this.isFacingLeft())
				chop.RotateBy(180.0f + chopAngle, Vec2f());
			else
				chop.RotateBy(chopAngle, Vec2f());
		}
	}

	//arm anims
	Vec2f armOffset = Vec2f(0.0f, 5.5f + config_offset);

	if (showgun)
	{
		f32 armangle = -angle;

		if (this.isFacingLeft())
		{
			armangle = 180.0f - angle;
		}

		while (armangle > 180.0f)
		{
			armangle -= 360.0f;
		}

		while (armangle < -180.0f)
		{
			armangle += 360.0f;
		}

		if (!blob.isKeyPressed(key_action1) && !blob.isKeyPressed(key_action2)) //running/walking
		{
			armOffset -= Vec2f(0.0f,Maths::Abs(blob.getVelocity().x)*0.5f);

			if (this.isFacingLeft())
			{
				armangle += Maths::Abs(blob.getVelocity().x)*-10.0f;
			}
			else
			{
				armangle += Maths::Abs(blob.getVelocity().x)*10.0f;
			}
		}
		
		if (!blob.isOnGround()) //in air
		{
			armOffset -= Vec2f(0,2);
		}
		else if (blob.isKeyPressed(key_action2)) //ads
		{
			armOffset -= Vec2f(2.5f, 1.0f);
		}
		
		DrawGun(this, blob, archer, armangle, armOffset);
	}
	else
	{
		setArmValues(this.getSpriteLayer("frontarm"), false, 0.0f, 0.1f, "default", Vec2f(0, 0), armOffset);
		//setArmValues(this.getSpriteLayer("backarm"), false, 0.0f, -0.1f, "default", Vec2f(0, 0), armOffset);
	}

	//set the head anim
	if (knocked || crouch)
	{
		blob.Tag("dead head");
	}
	else if (blob.isKeyPressed(key_action1) || blob.isKeyPressed(key_action2))
	{
		blob.Tag("attack head");
		blob.Untag("dead head");
	}
	else
	{
		blob.Untag("attack head");
		blob.Untag("dead head");
	}
}

void DrawGun(CSprite@ this, CBlob@ blob, ArcherInfo@ archer, f32 armangle, Vec2f armOffset)
{
	f32 sign = (this.isFacingLeft() ? 1.0f : -1.0f);
	CSpriteLayer@ frontarm = this.getSpriteLayer("frontarm");

	frontarm.animation.frame = 4;
	setArmValues(frontarm, true, armangle, 0.1f, "default", Vec2f(-4.0f * sign, 0.0f), armOffset + Vec2f(0.0f, (Maths::Abs(blob.getVelocity().x) >= 1.0f && blob.isOnGround()) ? ((getGameTime() % 8 < 4) ? -1.0f : 0.0f) : 0.0f));

	if (blob.getCarriedBlob() !is null)
	{
		frontarm.SetVisible(!blob.getCarriedBlob().hasTag("hidesgunonhold"));
	}

	frontarm.SetRelativeZ(1.5f);
	//setArmValues(this.getSpriteLayer("backarm"), true, armangle, -0.1f, "default", Vec2f(-4.0f * sign, 0.0f), armOffset);
}

bool IsFiring(CBlob@ blob)
{
	return blob.isKeyPressed(key_action1);
}

void onGib(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	Vec2f pos = blob.getPosition();
	Vec2f vel = blob.getVelocity();
	vel.y -= 3.0f;
	f32 hp = Maths::Min(Maths::Abs(blob.getHealth()), 2.0f) + 1.0f;
	const u8 team = blob.getTeamNum();
	CParticle@ Body     = makeGibParticle("SoldierGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 0, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Arm      = makeGibParticle("SoldierGibs.png", pos, vel + getRandomVelocity(90, hp - 0.2 , 80), 1, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Flesh   = makeGibParticle("SoldierGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 2, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
	CParticle@ Arm2    = makeGibParticle("SoldierGibs.png", pos, vel + getRandomVelocity(90, hp + 1 , 80), 3, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
}