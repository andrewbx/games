//-----------------------------------------------
// ShowNames v1.0
//-----------------------------------------------
// ** Corrected for display & team colours added.
// ** Inspired from ShowNames & Bongos Names.
//-----------------------------------------------
// Andrew (andrew@devnull.uk)
//-----------------------------------------------
class ShowNames expands Mutator;

function ModifyPlayer(Pawn Other)
{
    local Pawn P;
    local iShowNames iShowNames;
    Super.ModifyPlayer(Other);
    foreach AllActors(class'iShowNames', iShowNames)
    {
        If (iShowNames.owner == Other)
            Return;
    }
    Spawn(Class'iShowNames.iShowNames',other);
}

class iShowNames expands Mutator;

var bool init;
var byte inttime;

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (init)
    return;
    inttime++;
    if (inttime>10)
    {
        inttime=0;
        RegisterHUDMutator();
    }
}

simulated function RegisterHUDMutator()
{
    local HUD MyHud;
    local Pawn P;
    local playerpawn playerpawn;

    if (!init)
    {
        foreach AllActors(class'HUD', MyHud)
        {
            init = true;
            If (MyHud.owner != none)
            {
                If (MyHud.owner == owner)
                {
                    NextHUDMutator = MyHud.HUDMutator;
                    MyHud.HUDMutator = Self;
                    bHUDMutator = True;
                }
                else
                {
                    init = true;
                    return;
                }
            }
            else
            {
                init = true;
                return;
            }
        }
    }
}

simulated event PostRender(canvas Canvas)
{
    RenderNames(Canvas);
    if( nextHUDMutator != None )
    nextHUDMutator.PostRender(Canvas);
}

simulated function RenderNames(canvas Canvas)
{
    local RunePlayer P;
    local int SX,SY;
    local float scale, dist;
    local vector pos;

    foreach AllActors(class'RunePlayer', P)
    {
        pos = P.Location+vect(0,0,1.2)*P.CollisionHeight;
        if (!FastTrace(pos, Canvas.ViewPort.Actor.ViewLocation) || P == Canvas.ViewPort.Actor || P.IsA('CTTSpectator')
        || P.Health <= 0)
        continue;
        If (P.style == STY_Translucent)
        Continue;
        Canvas.TransformPoint(pos, SX, SY);
        if (SX > 0 && SX < Canvas.ClipX && SY > 0 && SY < Canvas.ClipY)
        {
            dist = VSize(P.Location-Canvas.ViewPort.Actor.ViewLocation);
            dist = FClamp(dist, 1, 10000);
            scale = 500.0/dist;
            scale = FClamp(scale, 0.01, 2.0);
            Canvas.SetPos(SX-(32*scale)*0.5, SY-(32*scale));
            Canvas.Font = Canvas.MedFont;

            if (P.PlayerReplicationInfo.Team==0)
            {
                Canvas.DrawColor.R = 255;
                Canvas.DrawColor.G = 100;
                Canvas.DrawColor.B = 100;
            }
            else if (P.PlayerReplicationInfo.Team==1)
            {
                Canvas.DrawColor.R = 100;
                Canvas.DrawColor.G = 100;
                Canvas.DrawColor.B = 255;
            }
            else if (P.PlayerReplicationInfo.Team==2)
            {
                Canvas.DrawColor.R = 100;
                Canvas.DrawColor.G = 255;
                Canvas.DrawColor.B = 100;
            }
            else if (P.PlayerReplicationInfo.Team==3)
            {
                Canvas.DrawColor.R = 255;
                Canvas.DrawColor.G = 255;
                Canvas.DrawColor.B = 100;
            }
            else
            {
                Canvas.DrawColor.R = 255;
                Canvas.DrawColor.G = 255;
                Canvas.DrawColor.B = 255;
            }
            Canvas.DrawText(P.PlayerReplicationInfo.PlayerName);
            Canvas.DrawColor.R = 255;
            Canvas.DrawColor.G = 255;
            Canvas.DrawColor.B = 255;
        }
    }
}
