void onInit(CBlob@ this)
{
	this.Tag("medium weight");
	this.Tag("trap"); // so bullets pass
}

void onTick(CBlob@ this)
{
	AttachmentPoint@ point = this.getAttachments().getAttachmentPointByName("PICKUP");
	if (point !is null)
	{
		CBlob@ b = point.getOccupied();
		if (b !is null && b.isMyPlayer())
		{
			b.set_u32("dont_change_zoom", getGameTime()+1);
			b.Tag("binoculars");
		}
	}
}