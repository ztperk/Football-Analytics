import pandas as pd

games = pd.read_csv("games.csv")
games2 = pd.read_csv("games2.csv")

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
