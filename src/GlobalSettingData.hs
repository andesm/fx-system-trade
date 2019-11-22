module GlobalSettingData where

data GlobalSettingData = GlobalSettingData
  { taRandomMargin     :: Int
  , taMiddleLongMargin :: Int
  , makeTreeCount      :: Int
  , algorithmRepeat    :: Int
  , learningTestCount  :: Int
  , treeAndRate        :: Int
  , treeOrRate         :: Int
  , countUpList        :: Double
  , maxTradeTime       :: Int
  , fxSettingLogNum    :: Int
  , gaNum              :: Int
  , quantityRate       :: Double
  , initalProperty     :: Double
  , productionMaxUnit  :: Int
  , practiceMaxUnit    :: Int
  , dbHost             :: String
  , spread             :: Double
  }

gsd :: GlobalSettingData
gsd =
  GlobalSettingData { taRandomMargin        = 5
                    , taMiddleLongMargin    = 6
                    , makeTreeCount         = 3
                    , algorithmRepeat       = 3
                    , learningTestCount     = 100
                    , countUpList           = 2
                    , quantityRate          = 5
                    , treeAndRate           = 1
                    , treeOrRate            = 1
                    , fxSettingLogNum       = 100
                    , gaNum                 = 100
                    , maxTradeTime          = 24 * 60 * 5
                    , initalProperty        = 3000000
                    , productionMaxUnit     = 3000000
                    , practiceMaxUnit       = 250000
                    , spread                = 0.008
                    , dbHost                = "openshift.flg.jp:30017"
                    --, dbHost                = "mongo:27017"
                    }




