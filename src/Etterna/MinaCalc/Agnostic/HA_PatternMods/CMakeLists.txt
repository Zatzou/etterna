list(APPEND HA_PATTERN_MODS
    "CJ.h"
    "CJDensity.h"
    "FlamJam.h"
    "HS.h"
    "HSDensity.h"
    "JS.h"
    "Stream.h"
    "TheThingFinder.h"
    "GenericChordstream.h")

target_sources(Etterna PUBLIC ${HA_PATTERN_MODS})