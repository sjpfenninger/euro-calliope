"""Rules to process transport sector data."""

rule download_transport_timeseries:
    message: "Get EV data from RAMP"
    params:
        url = config["data-sources"]["ev-data"]
    conda: "../envs/shell.yaml"
    output: protected("data/automatic/ramp-ev-consumption-profiles.csv.gz")
    localrule: True
    shell: "curl -sLo {output} {params.url}"

rule annual_transport_demand:
    message: "Calculate future transport energy demand based on JRC IDEES"
    input:
        energy_balances = "build/data/annual-energy-balances.csv",
        jrc_road_energy = "build/data/jrc-idees/transport/processed-road-energy.csv",
        jrc_road_distance = "build/data/jrc-idees/transport/processed-road-distance.csv",
        jrc_road_vehicles = "build/data/jrc-idees/transport/processed-road-vehicles.csv",
    params:
        fill_missing_values = config["parameters"]["transport"]["fill-missing-values"],
        efficiency_quantile = config["parameters"]["transport"]["future-vehicle-efficiency-percentile"]
    conda: "../envs/default.yaml"
    output:
        distance = "build/data/transport/annual-road-transport-distance-demand.csv",
        vehicles = "build/data/transport/annual-road-transport-vehicles.csv",
        efficiency = "build/data/transport/annual-road-transport-efficiency.csv",
        road_electricity_historic = "build/data/transport/annual-road-transport-historic-electrification.csv",
    script: "../scripts/transport/annual_transport_demand.py"


rule create_road_transport_timeseries:
    message: "Create timeseries for road transport demand"
    input:
        annual_data = "build/data/transport/annual-road-transport-distance-demand.csv",
        timeseries = "data/automatic/ramp-ev-consumption-profiles.csv.gz"
    params:
        first_year = config["scope"]["temporal"]["first-year"],
        final_year = config["scope"]["temporal"]["final-year"],
        power_scaling_factor = config["scaling-factors"]["power"],
        conversion_factor = lambda wildcards: config["parameters"]["transport"]["road-transport-conversion-factors"][wildcards.vehicle_type],
        historic = False,
        countries = config["scope"]["spatial"]["countries"],
    conda: "../envs/default.yaml"
    wildcard_constraints:
        vehicle_type = "light-duty-vehicles|heavy-duty-vehicles|coaches-and-buses|passenger-cars|motorcycles"
    output:
        main = "build/data/transport/timeseries/timeseries-{vehicle_type}.csv",
    script: "../scripts/transport/road_transport_timeseries.py"


use rule create_road_transport_timeseries as create_road_transport_timeseries_historic_electrification with:
    message: "Create timeseries for historic electrified road transport demand"
    input:
        annual_data = "build/data/transport/annual-road-transport-historic-electrification.csv",
        timeseries = "data/automatic/ramp-ev-consumption-profiles.csv.gz",
    params:
        first_year = config["scope"]["temporal"]["first-year"],
        final_year = config["scope"]["temporal"]["final-year"],
        power_scaling_factor = config["scaling-factors"]["power"],
        conversion_factor = lambda wildcards: config["parameters"]["transport"]["road-transport-conversion-factors"][wildcards.vehicle_type],
        historic = True,
        countries = config["scope"]["spatial"]["countries"],
    output:
        "build/data/transport/timeseries/timeseries-{vehicle_type}-historic-electrification.csv"


rule aggregate_timeseries: # TODO consider merge with other rules, as this is tiny atm
    message: "Aggregates timeseries for {wildcards.resolution} electrified road transport transport"
    input:
        time_series = (
            "build/data/transport/timeseries/timeseries-light-duty-vehicles.csv",
            "build/data/transport/timeseries/timeseries-heavy-duty-vehicles.csv",
            "build/data/transport/timeseries/timeseries-coaches-and-buses.csv",
            "build/data/transport/timeseries/timeseries-passenger-cars.csv",
            "build/data/transport/timeseries/timeseries-motorcycles.csv"),
        locations = "build/data/regional/units.csv",
        populations = "build/data/regional/population.csv"
    conda: "../envs/default.yaml"
    output:
        "build/models/{resolution}/timeseries/demand/electrified-road-transport.csv",
    script: "../scripts/transport/aggregate_timeseries.py"


use rule aggregate_timeseries as aggregate_timeseries_historic_electrified with:
    message: "Aggregates timeseries for {wildcards.resolution} historically electrified road transport"
    input:
        time_series = (
            "build/data/transport/timeseries/timeseries-light-duty-vehicles-historic-electrification.csv",
            "build/data/transport/timeseries/timeseries-coaches-and-buses-historic-electrification.csv",
            "build/data/transport/timeseries/timeseries-passenger-cars-historic-electrification.csv"),
        locations = "build/data/regional/units.csv",
        populations = "build/data/regional/population.csv"
    output:
        "build/models/{resolution}/timeseries/demand/road-transport-historic-electrification.csv"
