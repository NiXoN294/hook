local lang = ConfigurationMedicMod.Language
local sentences = ConfigurationMedicMod.Sentences
 
-- Delete the timer
hook.Add("PlayerDisconnected", "PlayerDisconnected.MedicMod", function( ply )
	
	StopMedicAnimation( ply )
	
	if ply.RagdollHeartMassage then
		 if IsValid( ply.RagdollHeartMassage ) && IsValid( ply.RagdollHeartMassage:GetOwner() ) then
            ply.RagdollHeartMassage:GetOwner().NextSpawnTime = CurTime() +  ply.RagdollHeartMassage:GetOwner().AddToSpawnTime
            ply.RagdollHeartMassage.IsHeartMassage = false
			net.Start("MedicMod.Respawn")
				net.WriteInt(ply.RagdollHeartMassage:GetOwner().NextSpawnTime,32)
			net.Send(ply.RagdollHeartMassage:GetOwner())
        end
	end
	
    if timer.Exists( "MedicMod"..ply:EntIndex() ) then
        timer.Destroy("MedicMod"..ply:EntIndex())
    end
   
    -- remove the death ragdoll
    if IsValid( ply.DeathRagdoll ) then
        if IsValid( ply.DeathRagdoll.Prop ) then
            ply.DeathRagdoll.Prop:Remove()
        end
        ply.DeathRagdoll:Remove()
    end
   
end)
 
 
-- Respawn
hook.Add("PlayerSpawn", "PlayerSpawn.MedicMod", function( ply )
   
    ply:SetBleeding( false )
    ply:SetHeartAttack( false )
    ply:SetPoisoned( false )
   
    if ply:GetFractures() then
        -- cure fractures
        for k, v in pairs( ply:GetFractures() ) do
            ply:SetFracture(false, k)
        end
    end
   
    -- remove the death ragdoll
    if IsValid( ply.DeathRagdoll ) then
        if IsValid( ply.DeathRagdoll.Prop ) then
            ply.DeathRagdoll.Prop:Remove()
        end
        ply.DeathRagdoll:Remove()
		if IsValid(ply.DeathRagdoll.Rope) then
			ply.DeathRagdoll.Rope:SetParent( nil )
			if ply.DeathRagdoll.Rope.Elec and IsValid( ply.DeathRagdoll.Rope.Elec ) then
				ply.DeathRagdoll.Rope.Elec:SetPatient( nil )
			end
		end
    end
   
    ply:UnSpectate()
	
	ply.NextSpawnTime = 0
   
end)
 
-- Stop death sound
hook.Add("PlayerDeathSound", "PlayerDeathSound.MedicMod", function()
   
    return true
   
end)
 
-- Bleeding
hook.Add("EntityTakeDamage", "EntityTakeDamage.MedicMod", function( ply, dmg )
 
    if not IsValid(ply) or not ply:IsPlayer() then return end
   
    local dmgtype = dmg:GetDamageType()
       
    -- break a bone
    if dmg:IsFallDamage() then
        if dmg:GetDamage() >= ConfigurationMedicMod.MinimumDamageToGetFractures then
            ply:SetFracture(true, HITGROUP_RIGHTLEG)
            ply:SetFracture(true, HITGROUP_LEFTLEG)
        end
    end
   
    if IsBleedingDamage( dmg ) and dmg:GetDamage() >= ConfigurationMedicMod.MinimumDamageToGetBleeding then
		ply:SetBleeding( true )
	end
   
    if IsPoisonDamage( dmg ) then ply:SetPoisoned( true ) end
   
end)
 
-- Set heart attack
hook.Add("DoPlayerDeath", "DoPlayerDeath.MedicMod", function( ply, att, dmg )
	bshield_remove(ply) 
	StopMedicAnimation( ply )
	if ply.RagdollHeartMassage then

		if IsValid( ply.RagdollHeartMassage ) && IsValid( ply.RagdollHeartMassage:GetOwner() ) then

			ply.RagdollHeartMassage:GetOwner().NextSpawnTime = CurTime() +  ply.RagdollHeartMassage:GetOwner().AddToSpawnTime
            ply.RagdollHeartMassage.IsHeartMassage = false

			net.Start("MedicMod.Respawn")
				net.WriteInt(ply.RagdollHeartMassage:GetOwner().NextSpawnTime,32)
			net.Send(ply.RagdollHeartMassage:GetOwner())

		end
		
	end
	
    local dmgtype = dmg:GetDamageType()
    local dmgimpact = dmg:GetDamage()
	
    if IsBleedingDamage( dmg ) or ConfigurationMedicMod.DamageBurn[dmgtype] then
        if dmgtype == DMG_MEDICMODBLEEDING then
            ply:MedicNotif(sentences["His heart no longer beats"][lang], 10)
        end
        ply:SetHeartAttack( true )
        ply:MedicNotif(sentences["You fell unconscious following a heart attack"][lang], 10)
    else
        if IsPoisonDamage(dmg) then
            ply:SetPoisoned( true )
        end
        if IsBleedingDamage( dmg ) and dmgimpact >= ConfigurationMedicMod.MinimumDamageToGetBleeding then
            ply:SetBleeding( true )
        end
        ply:SetHeartAttack( true )
        ply:MedicNotif(sentences["You fell unconscious following a heart attack"][lang], 10)
    end
end)
 
-- Create the death ragdoll, etc.
hook.Add("PlayerDeath", "PlayerDeath.MedicMod", function( victim, inf, att )   
    -- Save player weapons
    victim.WeaponsStripped = {}
    for k, v in pairs( victim:GetWeapons() ) do
        table.insert(victim.WeaponsStripped,v:GetClass())
    end
   
    -- set the next respawn time
    timer.Simple( 0, function() 
		
		local timebeforerespawn = CurTime()+ConfigurationMedicMod.TimeBeforeRespawnIfNoConnectedMedics
		
		for k, v in pairs( player.GetAll() ) do
			if table.HasValue( ConfigurationMedicMod.MedicTeams, v:Team() ) then
				timebeforerespawn = CurTime()+ConfigurationMedicMod.TimeBeforeRespawn
				break
			end
		end
		
		victim.NextSpawnTime = timebeforerespawn

		net.Start("MedicMod.Respawn")
			net.WriteInt(timebeforerespawn,32)
		net.Send(victim)
		
	end )
   
    if not IsValid( victim ) or not victim:GetHeartAttack() then return end
   
    if victim:InVehicle() then victim:ExitVehicle() end
   
    -- Create death ragdoll
    local rag = victim:CreateDeathRagdoll()
 
    -- Remove ragdoll ent
    timer.Simple(0.01, function()
        if(victim:GetRagdollEntity() != nil and victim:GetRagdollEntity():IsValid()) then
            victim:GetRagdollEntity():Remove()
        end
    end)
   
    -- Set the view on the ragdoll
    victim:Spectate( OBS_MODE_CHASE )
    victim:SpectateEntity( rag )
   
end)

hook.Add( "PlayerCanHearPlayersVoice", "PlayerCanHearPlayersVoice.MedicMod", function( listener, talker )
    if not listener:Alive() and listener.DeathRagdoll and IsValid( listener.DeathRagdoll ) then
        if listener.DeathRagdoll:GetPos():DistToSqr( talker:GetPos() ) < 250000 then
            return true
        else
            return false
        end
    end
end )

-- Determine if the player can respawn
hook.Add("PlayerDeathThink", "PlayerDeathThink.MedicMod", function( pl )
    if not ( pl.NextSpawnTime ) then pl.NextSpawnTime = 0 end
    if pl.NextSpawnTime == -1 then return false end
    if pl.NextSpawnTime > CurTime() then return false end
   
    if ConfigurationMedicMod.ForceRespawn then
        pl:Spawn()
    end
   
end)
 
hook.Add("PlayerSwitchWeapon", "PlayerSwitchWeapon.MedicMod", function( ply, old, new )
 
    if not IsValid( old ) or not IsValid( ply ) then return end
   
    -- prevent switch weapon if the player is doing a heart massage
    if old:GetClass() == "heart_massage" && ply:GetMedicAnimation() != 0 then
        return true
    end
    if ply.CantSwitchWeapon then
        return true
    end
    if ply.CantSwitchWeaponMF and ConfigurationMedicMod.CanBreakArms then
        return true
    end
   
end)
 
-- Start animations when player join
hook.Add("PlayerInitialSpawn", "PlayerInitialSpawn.MedicMod", function( ply )
   
    timer.Simple(10, function()
        net.Start("MedicMod.PlayerStartAnimation")
        net.Send( ply )
    end)
	
end)
 
-- When a player spawn an ambulance
hook.Add("PlayerSpawnedVehicle", "PlayerSpawnedVehicle.MedicMod", function( ply, ent )
 
    if not IsValid( ent ) then return end
   
    if ConfigurationMedicMod.Vehicles[ent:GetModel()] then
   
        local button = ents.Create("ambulance_button_medicmod")
        button:Spawn()
        button:SetPos( ent:LocalToWorld(ConfigurationMedicMod.Vehicles[ent:GetModel()].buttonPos) )
        button:SetAngles( ent:LocalToWorldAngles(ConfigurationMedicMod.Vehicles[ent:GetModel()].buttonAngle) )
        button:SetParent( ent )
       
        ent.Button = button
       
        local stretcher = ents.Create("stretcher_medicmod")
        stretcher:Spawn()
        stretcher:SetPos(ent:LocalToWorld(ConfigurationMedicMod.Vehicles[ent:GetModel()].stretcherPos))
        stretcher:SetAngles(ent:LocalToWorldAngles(ConfigurationMedicMod.Vehicles[ent:GetModel()].stretcherAngle))
        stretcher:SetParent( ent )
       
        if not ConfigurationMedicMod.Vehicles[ent:GetModel()].drawStretcher then
            stretcher:SetRenderMode( RENDERMODE_TRANSALPHA )
            stretcher:SetColor( Color(0,0,0,0) )
        end
       
        ent.Stretcher = stretcher
		ent.SpawnedStretcher = stretcher
       
    end
   
end)

-- Remove the stretcher when vehicle is removed
hook.Add("EntityRemoved", "EntityRemoved.MedicMod", function( ent )

	if not IsValid( ent ) then return end
	
	local stretch = ent.SpawnedStretcher or NULL
		
	if not IsValid( stretch ) then return end
	
	if stretch.ragdoll && IsValid( stretch.ragdoll ) then return end
	
	stretch:Remove()

end)
 
local FractureHitGroups = {
 
    [HITGROUP_LEFTLEG] = true,
    [HITGROUP_RIGHTLEG] = true,
    [HITGROUP_LEFTARM] = true,
    [HITGROUP_RIGHTARM] = true,
   
}
 
-- break a bone
hook.Add("ScalePlayerDamage", "ScalePlayerDamage.MedicMod", function(ply, hitgroup, dmg)
   
    if not FractureHitGroups[hitgroup] then return end
   
    if dmg:GetDamage() < ConfigurationMedicMod.MinimumDamageToGetFractures then return end
   
    ply:SetFracture( true, hitgroup )
   
end)
 
-- Save entities
local MedicModSavedEntities = {
    ["terminal_medicmod"] = true,
    ["radio_medicmod"] = true,
    ["npc_health_seller_medicmod"] = true,
    ["mural_defib_medicmod"] = true,
    ["electrocardiogram_medicmod"] = true,
    ["bed_medicmod"] = true,
}
 
-- Commands
hook.Add("PlayerSay", "PlayerSay.MedicMod", function(ply, text)
           
    if text == "!save_medicmod" and ply:GetUserGroup(GLADMIN, ZGLADMIN) then
       
        local MedicPos = {}
       
        for k, v in pairs(ents.GetAll()) do
           
            if not MedicModSavedEntities[v:GetClass()] then continue end
           
            MedicPos[#MedicPos + 1] = {
                pos = v:GetPos(),
                ang = v:GetAngles(),
                class = v:GetClass()
            }
           
            file.CreateDir("medicmod")
           
            file.Write("medicmod/save_ents.txt", util.TableToJSON(MedicPos))
			
			local filecontent = file.Read("medicmod/save_ents.txt", "DATA")
   
			ConfigurationMedicMod.SavedEnts =  util.JSONToTable(filecontent)
       
        end
       
        ply:MedicNotif("Entities saved!")
 
    end
   
    if text == "!remove_medicmod" and ply:GetUserGroup(GLADMIN, ZGLADMIN) then
   
        if file.Exists("medicmod/save_ents.txt", "DATA") then
       
            file.Delete( "medicmod/save_ents.txt" )
           
            ply:MedicNotif("Entities removed!")
       
        end
		
		local filecontent = file.Read("medicmod/save_ents.txt", "DATA") or ""
   
		ConfigurationMedicMod.SavedEnts =  util.JSONToTable(filecontent) or {}
   
    end
   
    if text == "!reviveme" and ply:GetUserGroup(GLADMIN, ZGLADMIN, SPECADMIN, STADMIN, ADMIN, MODER, DMODER) and ConfigurationMedicMod.CanUseReviveMeCommand then
		
        ply:MedicalRespawn()
   
    end
	
	if text == "!"..ConfigurationMedicMod.MedicCommand and table.HasValue( ConfigurationMedicMod.MedicTeams, ply:Team() ) then
		
        net.Start("MedicMod.OpenMedicMenu")
		net.Send( ply )
   
    end
   
end)
 
-- Init the list of ents to spawn
hook.Add("Initialize", "Initialize.MedicMod", function()
 
    if not file.Exists("medicmod/save_ents.txt", "DATA") then return end
   
    local filecontent = file.Read("medicmod/save_ents.txt", "DATA")
   
    ConfigurationMedicMod.SavedEnts =  util.JSONToTable(filecontent)
 
end)
 
-- spawn ents
hook.Add("InitPostEntity", "InitPostEntity.MedicMod", function()
 
    if not ConfigurationMedicMod.SavedEnts then return end
   
   timer.Simple(1, function()
		for k, v in pairs(ConfigurationMedicMod.SavedEnts) do
			local ent = ents.Create(v.class)
			ent:SetPos( v.pos )
			ent:SetAngles( v.ang )
			ent:SetPersistent( true )
			ent:Spawn()
			ent:SetMoveType( MOVETYPE_NONE )
		end
	end)
	
end)
 
hook.Add("PostCleanupMap", "PostCleanupMap.MedicMod", function()
 
    if not ConfigurationMedicMod.SavedEnts then return end
   
    for k, v in pairs(ConfigurationMedicMod.SavedEnts) do
        local ent = ents.Create(v.class)
        ent:SetPos( v.pos )
        ent:SetAngles( v.ang )
        ent:SetPersistent( true )
        ent:Spawn()
        ent:SetMoveType( MOVETYPE_NONE )
    end
 
end)

-- Can change job?
hook.Add("playerCanChangeTeam", "playerCanChangeTeam.MedicMod", function(ply)
	if ply.NextSpawnTime and ply.NextSpawnTime > CurTime() then return false end
	if ply.NextSpawnTime and ply.NextSpawnTime == -1 then return false end
	if ply:GetMedicAnimation() != 0 then return false end
end)
 
-- if someone change job
hook.Add("OnPlayerChangedTeam", "OnPlayerChangedTeam.MedicMod", function(ply, bef, after)
   
    if ConfigurationMedicMod.HealedOnChangingJob then
   
        ply:SetBleeding( false )
        ply:SetHeartAttack( false )
        ply:SetPoisoned( false )
       
        if ply:GetFractures() then
            -- cure fractures
            for k, v in pairs( ply:GetFractures() ) do
                ply:SetFracture(false, k)
            end
        end
       
        -- remove the death ragdoll
        if IsValid( ply.DeathRagdoll ) then
            if IsValid( ply.DeathRagdoll.Prop ) then
                ply.DeathRagdoll.Prop:Remove()
            end
            ply.DeathRagdoll:Remove()
        end
       
        ply:UnSpectate()
       
    else
       
        timer.Simple( 1, function()
            if ply:GetFractures() then
                for k, v in pairs( ply:GetFractures() ) do
                    ply:SetFracture(true, k)
                end
            end
           
        end)
       
    end
	
	if table.HasValue( ConfigurationMedicMod.MedicTeams, ply:Team() )  then
		ply:MedicNotif(sentences["You're now a medic, get help with"][lang].." !"..ConfigurationMedicMod.MedicCommand)
	end
   
end)