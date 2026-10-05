# I used the animation code from the following:
# Mohammed Shammeer, "nfl-tracks"
# GitHub: https://github.com/shammeer-s/nfl-tracks
# MIT License



import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter

# Data paths on hpc-student
tracking_path = "/projects/class/spoa4001_u01/SportsTrackingTransformer/data/BigDataBowl_2024/tracking_week_4.csv"
plays_path = "/projects/class/spoa4001_u01/SportsTrackingTransformer/data/BigDataBowl_2024/plays.csv"

# Target play
game_id = 2022100210
play_id = 2735

# Load data
tracking = pd.read_csv(tracking_path)
plays = pd.read_csv(plays_path)

# Filter to the requested play
play_tracking = tracking[
    (tracking["gameId"] == game_id) &
    (tracking["playId"] == play_id)
].copy()

play_info = plays[
    (plays["gameId"] == game_id) &
    (plays["playId"] == play_id)
].iloc[0]

print("Tracking rows:", len(play_tracking))
print("Frames:", play_tracking["frameId"].nunique())
print("Play:", play_info["playDescription"])


# Get frame IDs in order
frame_ids = sorted(play_tracking["frameId"].unique())

# Teams and player to highlight
offense = play_info["possessionTeam"]   # NYJ
defense = play_info["defensiveTeam"]    # PIT
breece_id = 54501

# Focus the x-axis around the actual play
x_min = max(0, play_tracking["x"].min() - 10)
x_max = min(120, play_tracking["x"].max() + 10)

# Set up figure
fig, ax = plt.subplots(figsize=(14, 7))

def draw_field():
    ax.set_facecolor("#2e8b57")  # green field
    ax.set_xlim(x_min, x_max)
    ax.set_ylim(0, 53.3)

    # Yard lines every 5 yards
    for yard in range(0, 121, 5):
        lw = 2 if yard % 10 == 0 else 0.8
        alpha = 0.7 if yard % 10 == 0 else 0.35
        ax.axvline(yard, color="white", linewidth=lw, alpha=alpha, zorder=0)

    # Hash marks
    for yard in range(1, 120):
        ax.plot([yard, yard], [22.91, 23.57], color="white", linewidth=0.8, alpha=0.6, zorder=0)
        ax.plot([yard, yard], [29.73, 30.39], color="white", linewidth=0.8, alpha=0.6, zorder=0)

    # Outer boundary
    ax.plot([0, 120], [0, 0], color="white", linewidth=2)
    ax.plot([0, 120], [53.3, 53.3], color="white", linewidth=2)
    ax.plot([0, 0], [0, 53.3], color="white", linewidth=2)
    ax.plot([120, 120], [0, 53.3], color="white", linewidth=2)

    # Yard numbers every 10 yards
    for yard in range(10, 111, 10):
        if x_min <= yard <= x_max:
            label = str(yard if yard <= 50 else 120 - yard)
            ax.text(yard, 5, label, color="white", fontsize=12, ha="center", va="center", alpha=0.8)
            ax.text(yard, 48.3, label, color="white", fontsize=12, ha="center", va="center", alpha=0.8)

    ax.set_xlabel("Field X")
    ax.set_ylabel("Field Y")


def animate(frame_id):
    ax.clear()
    draw_field()

    frame = play_tracking[play_tracking["frameId"] == frame_id]

    offense_df = frame[frame["club"] == offense]
    defense_df = frame[frame["club"] == defense]
    football_df = frame[frame["club"] == "football"]
    breece_df = frame[frame["nflId"] == breece_id]

    # Team colors
    ax.scatter(offense_df["x"], offense_df["y"], s=140, c="#125740", edgecolors="white", linewidths=0.8, label=offense, zorder=3)
    ax.scatter(defense_df["x"], defense_df["y"], s=140, c="#FFB612", edgecolors="black", linewidths=0.8, marker="s", label=defense, zorder=3)

    # Football
    ax.scatter(football_df["x"], football_df["y"], s=70, c="#8B4513", marker="D", edgecolors="black", linewidths=0.8, label="Football", zorder=4)

    # Highlight Breece Hall
    if not breece_df.empty:
        ax.scatter(breece_df["x"], breece_df["y"], s=260, facecolors="none", edgecolors="red", linewidths=2.5, zorder=5)
        ax.text(
            breece_df["x"].iloc[0],
            breece_df["y"].iloc[0] + 2.0,
            "Breece Hall",
            color="red",
            fontsize=10,
            ha="center",
            fontweight="bold",
            zorder=6
        )

    # Jersey numbers
    for _, row in frame[frame["club"] != "football"].iterrows():
        if pd.notna(row["jerseyNumber"]):
            ax.text(
                row["x"],
                row["y"],
                str(int(row["jerseyNumber"])),
                ha="center",
                va="center",
                fontsize=7,
                color="white" if row["club"] == offense else "black",
                fontweight="bold",
                zorder=4
            )

    # Current event
    events = frame["event"].dropna().unique()
    event_text = events[0] if len(events) > 0 else "in_play"

    ax.set_title(
        f"Game {game_id} | Play {play_id} | Frame {frame_id} | Event: {event_text}",
        fontsize=13,
        fontweight="bold"
    )

    # Play description
    ax.text(
        0.5, 1.02,
        play_info["playDescription"],
        transform=ax.transAxes,
        ha="center",
        va="bottom",
        fontsize=10
    )

    ax.legend(loc="upper right")


animation = FuncAnimation(
    fig,
    animate,
    frames=frame_ids,
    interval=120
)

output_path = "DTSC_5010_HW5/HW5_question2.gif"

animation.save(
    output_path,
    writer=PillowWriter(fps=8)
)

plt.close()

print(f"GIF saved to: {output_path}")
