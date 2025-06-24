import pandas as pd
import matplotlib.pyplot as plt

def plot_normalized_output_power(data):
    """
    Plots i_wvl vs o_pwr / i_pwr from a CSV file path or DataFrame.
    
    Parameters:
    - data: str (CSV file path) or pandas.DataFrame
    """
    if isinstance(data, str):
        df = pd.read_csv(data)
    elif isinstance(data, pd.DataFrame):
        df = data
    else:
        raise TypeError("Input must be a file path or a pandas DataFrame.")

    df['normalized_power'] = df['o_pwr'] / df['i_pwr']

    plt.figure()
    plt.plot(df['i_wvl'], df['normalized_power'], marker='o')
    plt.xlabel('Wavelength (nm)')
    plt.ylabel('Normalized Output Power (o_pwr / i_pwr)')
    plt.title('Normalized Output Power vs Wavelength')
    plt.grid(True)
    plt.show()

