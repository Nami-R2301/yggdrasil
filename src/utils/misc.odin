package utils;

import "core:math";
import "base:runtime";

import types "../types";

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////// HELPERS /////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////


// A generic procedure to check if the value provided would overflow the alias used for IDs.
//
// @param   Value to test overflow with current types.Id alias size.
// @return  If the value provided would overflow with the current types.Id encoding.
_check_id_overflow :: proc(value: $T) -> bool {
    // Only unsigned.
    switch size_of(types.Id) {
        case 1: return value > 255
        case 2: return value > 65_535
        case 4: return value > 4_294_967_295
        case 8: return value > 9_223_372_036_854_775_807
    }

    // If it's not a numeric type we handle, return failure.
    return true
}

// A generic procedure to get the max value of any number.
//
// @param   Type to get maximum possible value out of.
// @return  The maximum value for that number type in float to support floats as well.
_get_max_number :: proc($T: typeid) -> f64 {
    info := runtime.__type_info_of(T);

    #partial switch variant in info.variant {
        case runtime.Type_Info_Integer:
            if variant.signed {
                switch size_of(T) {
                    case 1: return 127;
                    case 2: return 32_767;
                    case 4: return 2_147_483_647;
                    case 8: return 9_223_372_036_854_775_807;
                }
            } else {
                switch size_of(T) {
                    case 1: return 255;
                    case 2: return 65_535;
                    case 4: return 4_294_967_295;
                    case 8: return 18_446_744_073_709_551_614;
                }
            }
        case runtime.Type_Info_Float:
            switch size_of(T) {
                case 4: return math.F32_MAX;
                case 8: return math.F64_MAX;
            }
    }
    return 0
}