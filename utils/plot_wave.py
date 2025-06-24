from typing import List, Dict
import pandas as pd
import matplotlib.pyplot as plt
import argparse

def load_data(csv_path: str) -> pd.DataFrame:
    """Load the monitor CSV into a DataFrame."""
    return pd.read_csv(csv_path)

def map_states(df: pd.DataFrame, state_col: str) -> Dict:
    """
    Map each unique state string to an integer code, store in 'state_code' column.
    Returns the mapping Dict.
    """
    unique_states = df[state_col].unique()
    state_map = {name: idx for idx, name in enumerate(unique_states)}
    df['state_code'] = df[state_col].map(state_map)
    return state_map

def plot_monitor(
    df: pd.DataFrame,
    time_col: str,
    numeric_cols: List[str],
    state_col: str,
    state_map: Dict[str,int]
):
    """
    Create a vertical stack of subplots: one for each numeric column, then the state timeline.
    """
    total_plots = len(numeric_cols) + 1
    fig, axes = plt.subplots(total_plots, 1, sharex=True, figsize=(8, 2.5 * total_plots))

    # Plot each numeric series
    for ax, col in zip(axes, numeric_cols):
        ax.plot(df[time_col], df[col])
        ax.set_ylabel(col)
        ax.grid(True)

    # Final plot: stepped state timeline
    ax = axes[-1]
    ax.step(df[time_col], df['state_code'], where='post')
    ax.set_ylabel(state_col)
    ax.set_yticks(list(state_map.values()))
    ax.set_yticklabels(list(state_map.keys()))
    ax.set_xlabel(time_col)
    ax.grid(True)

    fig.tight_layout()
    plt.show()

def main():
    p = argparse.ArgumentParser(
        description="Plot search_monitor CSV with time-series and state timeline"
    )
    p.add_argument("csv_file", help="Path to CSV (with 'time_ps' and 'state' columns)")
    p.add_argument(
        "--time_col", default="time_ps",
        help="Name of the time column (default: time_ps)"
    )
    p.add_argument(
        "--state_col", default="state",
        help="Name of the state column (default: state)"
    )
    args = p.parse_args()

    # 1) Load CSV
    df = load_data(args.csv_file)

    # 2) Map & encode the state strings
    state_map = map_states(df, args.state_col)

    # 3) Determine which columns to plot as numeric series
    excluded = {args.time_col, args.state_col, 'state_code'}
    numeric_cols = [
        col for col in df.columns
        if col not in excluded and pd.api.types.is_numeric_dtype(df[col])
    ]

    # 4) Plot
    plot_monitor(df, args.time_col, numeric_cols, args.state_col, state_map)

if __name__ == "__main__":
    main()
