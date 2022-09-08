#include "TDM_Structs.as";

/*
void onTick( CRules@ this )
{
    //see the logic script for this
}
*/

void onInit(CRules@ this)
{
	CBitStream stream;
	stream.write_u16(0xDEAD);
	this.set_CBitStream("tdm_serialised_team_hud", stream);
}

shared class FlagsInfo {
    bool flagMatch = getBlobByName("pointflag") !is null;

    u8 getFlagsCount(u8 team, bool total)
    {
        CBlob@[] flags;
        getBlobsByName("pointflag", @flags);
        u8 cock = 0;
        for (u8 i = 0; i < flags.length; i++)
        {
            if (flags[i] is null) continue;
            if (flags[i].getTeamNum() != team) continue;
            cock++;
        }
        return cock;
    }

	bool done_sorting = false;

    void renderFlagIcons(Vec2f start_pos)
    {
        CBlob@[] flags;
        getBlobsByName("pointflag", @flags);


		if (getGameTime() < 300 || !getRules().get_bool("done_sorting"))
		{
			f32[] pos;

			for (u8 i = 0; i < flags.length; i++)
        	{
        	    CBlob@ flag = flags[i];
        	    if (flag is null) continue;
				f32 posx = flag.getPosition().x;
				pos.push_back(posx);
			}

			for (u16 i = 0; i < pos.length-1; i++) // sort with swapping positions change icons positions
			{
				if (pos[i] > pos[i+1])
				{
					Vec2f bpos = flags[i].getPosition();
					f32 temp = pos[i];

					pos[i] = pos[i+1];
					pos[i+1] = temp;
					flags[i].setPosition(flags[i+1].getPosition());
					flags[i].getShape().SetPosition(flags[i+1].getShape().getPosition()); // shape position is needed, otherwise wrong HUD
					flags[i+1].setPosition(bpos);
					flags[i+1].getShape().SetPosition(bpos);

					i = 0;
				}
				if (i == flags.length-2)
				{
					getRules().set_bool("done_sorting", true);
				}
			}
		}		

        for (u8 i = 0; i < flags.length; i++)
        {
        	CBlob@ flag = flags[i];
            if (flag is null) continue;
			
            u8 icon_idx;
            u8 team_num = flag.getTeamNum();
            u8 team_state = team_num; // team index | 255 neutral | 2 capping

            if (flag.get_s8("teamcapping") != -1
            && flag.get_s8("teamcapping") != team_num)
            {
                team_state = 2; // alert!!!
            }

			GUI::DrawIcon("CTFGui.png", 0, Vec2f(16,32), start_pos + Vec2f(36.0f*i, 0), 1.0f, team_num);
            if (team_state == 2) GUI::DrawIcon("CTFGui.png", 1, Vec2f(16,32), start_pos + Vec2f(36.0f*i + 2, 48), 1.0f, team_num);
        }
    }
};

void onRender(CRules@ this)
{
	if (g_videorecording)
		return;

	CPlayer@ p = getLocalPlayer();

	if (p is null || !p.isMyPlayer()) { return; }

	GUI::SetFont("menu");

	CBitStream serialised_team_hud;
	this.get_CBitStream("tdm_serialised_team_hud", serialised_team_hud);

	if (serialised_team_hud.getBytesUsed() > 10)
	{
		serialised_team_hud.Reset();
		u16 check;

		if (serialised_team_hud.saferead_u16(check) && check == 0x5afe)
		{
			const string gui_image_fname = "Rules/TDM/TDMGui.png";

			while (!serialised_team_hud.isBufferEnd())
			{
				TDM_HUD hud(serialised_team_hud);
				Vec2f topLeft = Vec2f(8, 8 + 64 * hud.team_num);
				GUI::DrawIcon(gui_image_fname, 0, Vec2f(128, 32), topLeft, 1.0f, hud.team_num);
				
				FlagsInfo flags_info;
    			if (flags_info !is null)
    			{
    			    flags_info.renderFlagIcons(Vec2f(16, 140));
    			}

				int team_player_count = 0;
				int team_dead_count = 0;
				int step = 0;
				Vec2f startIcons = Vec2f(64, 8);
				Vec2f startSkulls = Vec2f(160, 8);
				string player_char = "";
				int size = int(hud.unit_pattern.size());

				while (step < size)
				{
					player_char = hud.unit_pattern.substr(step, 1);
					step++;

					if (player_char == " ") { continue; }

					if (player_char != "s")
					{
						int player_frame = 1;

						if (player_char == "a")
						{
							player_frame = 2;
						}

						GUI::DrawIcon(gui_image_fname, 12 + player_frame, Vec2f(16, 16), topLeft + startIcons + Vec2f(team_player_count * 8, 0) , 1.0f, hud.team_num);
						team_player_count++;
					}
					else
					{
						GUI::DrawIcon(gui_image_fname, 12 , Vec2f(16, 16), topLeft + startSkulls + Vec2f(team_dead_count * 16, 0) , 1.0f, hud.team_num);
						team_dead_count++;
					}
				}

				if (hud.spawn_time != 255)
				{
					string time = "" + hud.spawn_time;
					GUI::DrawText(time, topLeft + Vec2f(196, 42), SColor(255, 255, 255, 255));
				}

				string kills = getTranslatedString("WARMUP");

				if (hud.kills_limit > 0)
				{
					kills = getTranslatedString("KILLS: {CURRENT}/{LIMIT}").replace("{CURRENT}", "" + hud.kills).replace("{LIMIT}", "" + hud.kills_limit);
				}
				else if (hud.kills_limit == -2)
				{
					kills = getTranslatedString("SUDDEN DEATH");
				}

				GUI::DrawText(kills, topLeft + Vec2f(64, 42), SColor(255, 255, 255, 255));
			}
		}

		serialised_team_hud.Reset();
	}

	string propname = "tdm spawn time " + p.getUsername();
	if (p.getBlob() is null && this.exists(propname))
	{
		u8 spawn = this.get_u8(propname);

		if (spawn != 255)
		{
			if (spawn == 254)
			{
				GUI::DrawText(getTranslatedString("In Queue to Respawn...") , Vec2f(getScreenWidth() / 2 - 70, getScreenHeight() / 3 + Maths::Sin(getGameTime() / 3.0f) * 5.0f), SColor(255, 255, 255, 55));
			}
			else if (spawn == 253)
			{
				GUI::DrawText(getTranslatedString("No Respawning - Wait for the Game to End.") , Vec2f(getScreenWidth() / 2 - 180, getScreenHeight() / 3 + Maths::Sin(getGameTime() / 3.0f) * 5.0f), SColor(255, 255, 255, 55));
			}
			else
			{
				GUI::DrawText(getTranslatedString("Respawning in: {SEC}").replace("{SEC}", "" + spawn), Vec2f(getScreenWidth() / 2 - 70, getScreenHeight() / 3 + Maths::Sin(getGameTime() / 3.0f) * 5.0f), SColor(255, 255, 255, 55));
			}
		}
	}
}
