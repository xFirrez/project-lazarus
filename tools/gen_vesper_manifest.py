# Regenerates game/maps/vesper_peak/markers_manifest.json from the zone scripts (Step 8, AC-8.6).
# Run from game/: python3 ../tools/gen_vesper_manifest.py
import re,glob,json
markers=[]
for p in sorted(glob.glob('maps/vesper_peak/zones/*.gd')):
    zone=re.search(r'zones/(Z\d\d)',p).group(1)
    for m in re.finditer(r'mark\(\s*&"([a-z_]+)",\s*"([A-Za-z0-9_%]+)"', open(p).read()):
        k,i=m.groups()
        if '%' in i:
            n={'EE_Symbol_%d':4,'EE_Node_%d':4,'EE_Pylon_%d':3}[i]
            for j in range(1,n+1): markers.append({"id":i%j,"kind":k,"zone":zone})
        else: markers.append({"id":i,"kind":k,"zone":zone})
doors={"D01":750,"D02":1000,"D03":1000,"D04":1250,"D05":1250,"D06":1250,"D07":1000,"D08":1250,"D09":1000,"D10":1000,"D11":1500,"D12":1250,"D14":2000,"D15":1500}
man={"map":"vesper_peak","doc":"docs/VESPER_PEAK.md (§2-7). Checked by tests/integration/test_vesper_markers.gd (AC-8.6).",
"zones":["Z01","Z03","Z04","Z05","Z06","Z07","Z08","Z09","Z10","Z11","Z12","Z13"],
"doors":[{"id":k,"cost":v} for k,v in doors.items()],
"door_total":sum(doors.values()),
"wall_buys_live":["WallBuy_M14","WallBuy_Coachgun"],
"nodes":["PWR_MainSwitch","GND_Gondola","GND_Console_Z01","GND_Console_Z07","GND_CabinPanel","LFT_FreightLift","LFT_Console0","LFT_Console1","CHT_LaundryChute","CHT_Grate","CHT_GrateTarget","BRG_ReactorBridge"],
"markers":markers}
json.dump(man,open('maps/vesper_peak/markers_manifest.json','w'),indent=1)
print(len(markers))
