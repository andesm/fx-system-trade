module GlobalSettingData where

data GlobalSettingData = GlobalSettingData
  { taRandomMargin     :: Int
  , taMiddleLongMargin :: Int
  , makeTreeCount      :: Int
  , algorithmRepeat    :: Int
  , treeAndRate        :: Int
  , treeOrRate         :: Int
  , countUpList        :: Double
  , learningTestTimes  :: Int
  , learningTestCount  :: Int
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
  GlobalSettingData { taRandomMargin        = 3
                    , taMiddleLongMargin    = 3
                    , makeTreeCount         = 3
                    , algorithmRepeat       = 3
                    , countUpList           = 3
                    , treeAndRate           = 1
                    , treeOrRate            = 1
                    , learningTestTimes     = 10
                    , learningTestCount     = 40
                    , fxSettingLogNum       = 50
                    , quantityRate          = 3
                    , gaNum                 = 10
                    , maxTradeTime          = 24 * 60
                    , initalProperty        = 1000000
                    , productionMaxUnit     = 3000000
                    , practiceMaxUnit       = 250000
                    , spread                = 0.008
                    --, dbHost                = "openshift.flg.jp:30017"
                    , dbHost                = "mongo:27017"
                    }

