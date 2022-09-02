#include "ParticleSparks.as";

void onInit(CBlob@ this)
{
	this.Tag("explosive");
	this.maxQuantity = 1;

	AttachmentPoint@ ap = this.getAttachments().getAttachmentPointByName("PICKUP");
	if (ap !is null)
	{
		ap.SetKeysToTake(key_action3);
	}
}

bool canBePutInInventory(CBlob@ this, CBlob@ inventoryBlob)
{
	return true;
}

void onTick(CBlob@ this)
{
	if (this.isAttached() && !this.hasTag("activated"))
	{
		AttachmentPoint@ ap = this.getAttachments().getAttachmentPointByName("PICKUP");
		if (ap !is null && ap.isKeyJustPressed(key_action3))
		{
			//if (!this.hasTag("no_pin")) Sound::Play("/Pinpull.ogg", this.getPosition(), 0.8f, 1.0f);
			CBitStream params;
			this.SendCommand(this.getCommandID("activate"), params);
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
    if (cmd == this.getCommandID("activate"))
    {
		if (isClient() && !this.hasTag("activated"))
		{
			this.getSprite().PlaySound("Lighter_Use", 1.00f, 0.90f + (XORRandom(100) * 0.30f));
			sparks(this.getPosition(), 1, 0.25f);
		}

		this.Tag("activated");
		
        if(isServer())
        {
    		AttachmentPoint@ point = this.getAttachments().getAttachmentPointByName("PICKUP");
            if (point !is null)
			{
				CBlob@ holder = point.getOccupied();
				if (holder !is null && this !is null)
				{
					CBlob@ blob = server_CreateBlob("molotov", this.getTeamNum(), this.getPosition());
					holder.server_Pickup(blob);
					this.server_Die();
					
					CPlayer@ activator = holder.getPlayer();
					string activatorName = activator !is null ? (activator.getUsername() + " (team " + activator.getTeamNum() + ")") : "<unknown>";
					//printf(activatorName + " has activated " + this.getName());
				}
			}
        }
    }
}