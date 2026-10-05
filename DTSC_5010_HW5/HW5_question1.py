import pandas as pd

original_path = "/projects/class/spoa4001_u01/SportsTrackingTransformer/data/BigDataBowl_2024/games.csv"
modified_path = "/projects/class/spoa4001_u01/SportsTrackingTransformer/data/BigDataBowl_2024/games2.csv"

games = pd.read_csv(original_path)
games2 = pd.read_csv(modified_path)

# Filter to Week 6 Chargers vs Broncos
original_game = games[
    (games["week"] == 6)
    & (
        ((games["homeTeamAbbr"] == "LAC") & (games["visitorTeamAbbr"] == "DEN"))
        | ((games["homeTeamAbbr"] == "DEN") & (games["visitorTeamAbbr"] == "LAC"))
    )
]

modified_game = games2[
    (games2["week"] == 6)
    & (
        ((games2["homeTeamAbbr"] == "LAC") & (games2["visitorTeamAbbr"] == "DEN"))
        | ((games2["homeTeamAbbr"] == "DEN") & (games2["visitorTeamAbbr"] == "LAC"))
    )
]

print("ORIGINAL GAME")
print(
    original_game[
        [
            "gameId",
            "week",
            "homeTeamAbbr",
            "visitorTeamAbbr",
            "homeFinalScore",
            "visitorFinalScore",
        ]
    ]
)

print("\nMODIFIED GAME")
print(
    modified_game[
        [
            "gameId",
            "week",
            "homeTeamAbbr",
            "visitorTeamAbbr",
            "homeFinalScore",
            "visitorFinalScore",
        ]
    ]
)
