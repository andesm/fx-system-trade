module GlobalSettingData where

data GlobalSettingData = GlobalSettingData
  { taMargin              :: Int
  , makeTreeCount         :: Int
  , algorithmRepeat       :: Int
  , learningTestCount     :: Int
  , thresholdRate         :: Double
  , countUpListMax        :: Int
  , tradePracticeBearer   :: String
  , tradePracticeUrl      :: String
  , tradeProductionBearer :: String
  , tradeProductionUrl    :: String
  , quantityRate          :: Double
  , initalProperty        :: Double
  , maxUnit               :: Int
  , dbHost                :: String
  , spread                :: Double
  }

gsd :: GlobalSettingData
gsd =
  GlobalSettingData { taMargin              = 4
                    , makeTreeCount         = 4
                    , algorithmRepeat       = 4
                    , countUpListMax        = 4
                    , learningTestCount     = 4
                    , quantityRate          = 5
                    , thresholdRate         = 0.1
                    , initalProperty        = 500000
                    , maxUnit               = 3000000
                    , spread                = 0.004
                    , dbHost                = "mongo:27017"
                    , tradePracticeBearer   = "Bearer b8831e8a4c0974fc5207eb9c4d844845-96edf86dff693710db11e5a333c18117"
                    , tradePracticeUrl      = "https://api-fxpractice.oanda.com/v1/accounts/6716490"
                    , tradeProductionBearer = "Bearer b8831e8a4c0974fc5207eb9c4d844845-96edf86dff693710db11e5a333c18117"
                    , tradeProductionUrl    = "https://api-fxpractice.oanda.com/v1/accounts/6716490"
                    }

