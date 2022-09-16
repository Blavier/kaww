const string classname = "Sniper"; // case sensitive

// DAMAGE
const float damage_body = 1.0f;
const float damage_head = 2.0f;
// SHAKE
const float recoilx = 14; // x shake (20)
const float recoily = 80; // y shake (45)
const float recoillength = 600; // how long to recoil (?)
// RECOIL
const float recoilforce = 0.03f; // amount to push player
const u8 recoilcursor = 13; // amount to raise mouse pos
const u8 sidewaysrecoil = 2; // sideways recoil amount
const u8 sidewaysrecoildamp = 8; // higher number means less sideways recoil
const float adscushionamount = 1.0f; // lower means less recoil when aiming down sights. 1.0 is no change

// spray pattern in logic

const float lengthofrecoilarc = 1.5f; // 2.0 is regular, -- 1.5 long arc   -- ak is 1.65

// ACCURACY
const u8 inaccuracycap = 80; // max amount of inaccuracy
const u8 inaccuracypershot = 50; // aim inaccuracy  (+3 per shot)
// delayafterfire + randdelay + 1 = no change in accuracy when holding lmb down

const bool semiauto = false;

const s8 reloadtime = 58; // time to reload
const string reloadsfx = classname + "_reload.ogg";
const string shootsfx = "Carbine_shoot.ogg";

const u8 delayafterfire = 38; // time between shots 4
const u8 randdelay = 4; // + randomness

const float bulletvelocity = 3.2f; // speed that bullets fly 1.6

namespace ArcherParams
{
	enum Aim
	{
		not_aiming = 0,
		readying,
		charging,
		fired,
		no_ammo,
		stabbing
	}
}

namespace ArrowType
{
	enum type
	{
		normal = 0,
		count
	};
}

class ArcherInfo
{
	s8 charge_time;
	u8 charge_state;

	bool isStabbing;
	bool isReloading;

	ArcherInfo()
	{
		charge_time = 0;
		charge_state = 0;
	}
};

const string[] arrowTypeNames = { "mat_arrows" };

const string[] arrowNames = { "Ammo", };



namespace Strategy
{
	enum strategy_type
	{
		idle = 0,
		attack_blob,
		goto_blob,
		find_healing,
		find_drill,
		dodge_spike,
		runaway
	};
};

const f32 SEEK_RANGE = 700.0f;
const f32 ENEMY_RANGE = 400.0f;

// Show emotes?
const bool USE_EMOTES = true;