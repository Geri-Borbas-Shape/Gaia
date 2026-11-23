import Foundation

/// Common names of well-known nearby stars, keyed by Gaia DR3 source identifier.
///
/// Gaia carries no names, so this table is kept by hand.
enum StarNames {

    static let bySourceID: [Int64: String] = [
        5853498713190525696: "Proxima Centauri",
        4472832130942575872: "Barnard's Star",
        3864972938605115520: "Wolf 359",
        762815470562110464: "Lalande 21185",
        2947050466531873024: "Sirius B",
        4075141768785646848: "Ross 154",
        1926461164913660160: "Ross 248",
        5164707970261890560: "Epsilon Eridani",
        6553614253923452800: "Lacaille 9352",
        3796072592206250624: "Ross 128",
        1872046609345556480: "61 Cygni A",
        1872046574983497216: "61 Cygni B",
        2154880616774131840: "Struve 2398 A",
        2154880616774131712: "Struve 2398 B",
        385334230892516480: "Groombridge 34",
        6412595290592307840: "Epsilon Indi",
        2452378776434477184: "Tau Ceti",
        2358524597030794112: "YZ Ceti",
        3139847906307949696: "Luyten's Star",
        4810594479418041856: "Kapteyn's Star",
        6583272171336048640: "Lacaille 8760",
        4330690742322011520: "Wolf 1061",
        2552928187080872832: "Van Maanen's Star",
        1637645127018395776: "Gliese 687",
        5951824121022278144: "Gliese 674",
        2603090003484152064: "Gliese 876",
        778947814402602752: "Gliese 412 A",
        823773494718931968: "Groombridge 1618",
        6562924609150908416: "Gliese 832",
        5955305209191546112: "Gliese 682",
        1934263333784036736: "EV Lacertae",
        5332606522595645952: "LP 145-141"
    ]
}
