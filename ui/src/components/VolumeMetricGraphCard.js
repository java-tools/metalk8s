import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import styled from 'styled-components';
import { LineChart, Dropdown } from '@scality/core-ui';
import {
  fetchVolumeStatsAction,
  updateVolumeStatsAction,
} from '../ducks/app/monitoring';
import {
  fontSize,
  padding,
  fontWeight,
} from '@scality/core-ui/dist/style/theme';
import {
  jointDataPointBaseonTimeSeries,
  addMissingDataPoint,
} from '../services/utils';
import {
  VOLUME_CONDITION_LINK,
  LAST_SEVEN_DAYS,
  LAST_TWENTY_FOUR_HOURS,
  LAST_ONE_HOUR,
  SAMPLE_DURATION_LAST_SEVEN_DAYS,
  SAMPLE_DURATION_LAST_TWENTY_FOUR_HOURS,
  SAMPLE_DURATION_LAST_ONE_HOUR,
  SAMPLE_FREQUENCY_LAST_SEVEN_DAYS,
  SAMPLE_FREQUENCY_LAST_TWENTY_FOUR_HOURS,
  SAMPLE_FREQUENCY_LAST_ONE_HOUR,
} from '../constants';
import { intl } from '../translations/IntlGlobalProvider';

const MetricGraphCardContainer = styled.div`
  min-height: 270px;
  background-color: ${(props) => props.theme.brand.primaryDark1};
  margin: ${padding.small};
  padding-bottom: ${padding.large};
`;

const MetricGraphTitle = styled.div`
  color: ${(props) => props.theme.brand.textPrimary};
  font-size: ${fontSize.base};
  font-weight: ${fontWeight.bold};
  padding: ${padding.small} 0 0 ${padding.large};
  display: flex;
  .sc-dropdown {
    padding-left: 25px;
  }
`;

const GraphsContainer = styled.div`
  display: flex;
  flex-direction: column;
  padding-left: ${padding.small};
`;

const RowGraphContainer = styled.div`
  display: flex;
  flex-direction: row;
  padding-left: 3px;
`;

const SecondRowGraphContainer = styled.div`
  display: flex;
  flex-direction: row;
  padding-left: 3px;
`;

const GraphTitle = styled.div`
  font-size: ${fontSize.small};
  font-weight: ${fontWeight.bold};
  color: ${(props) => props.theme.brand.textSecondary};
  padding: ${padding.small} 0 0 ${padding.larger};
`;

const UsageGraph = styled.div`
  min-width: 308px;
`;

const LatencyGraph = styled.div`
  min-width: 308px;
  padding-left: ${padding.large};
`;

const TroughputGraph = styled.div`
  min-width: 308px;
`;

const IOPSGraph = styled.div`
  min-width: 308px;
  padding-left: ${padding.large};
`;

// No data rendering should be extracted to an common style
const NoMetricsText = styled.div`
  color: ${(props) => props.theme.brand.textPrimary};
  font-size: ${fontSize.base};
  padding: ${padding.small} 0 0 ${padding.larger};
`;

const MetricGraphCard = (props) => {
  const {
    volumeStorageCapacity,
    volumeCondition,
    volumeMetricGraphData,
  } = props;
  const dispatch = useDispatch();
  const metricsTimeSpan = useSelector(
    (state) => state.app.monitoring.volumeStats.metricsTimeSpan,
  );

  const updateMetricsGraph = () => dispatch(fetchVolumeStatsAction());

  const queryStartingTime = volumeMetricGraphData?.queryStartingTime;
  // the item chosed by the metrics time span dropdown
  // we should have a unified unit, second, for all the props related to prometheus
  let sampleDuration = null;
  let sampleFrequency = null;

  if (metricsTimeSpan === LAST_SEVEN_DAYS) {
    // do the query every 1 hour
    sampleDuration = SAMPLE_DURATION_LAST_SEVEN_DAYS;
    sampleFrequency = SAMPLE_FREQUENCY_LAST_SEVEN_DAYS;
  } else if (metricsTimeSpan === LAST_TWENTY_FOUR_HOURS) {
    // do the query every 1 minute
    sampleDuration = SAMPLE_DURATION_LAST_TWENTY_FOUR_HOURS;
    sampleFrequency = SAMPLE_FREQUENCY_LAST_TWENTY_FOUR_HOURS;
  } else if (metricsTimeSpan === LAST_ONE_HOUR) {
    // do the query every 1 second
    sampleDuration = SAMPLE_DURATION_LAST_ONE_HOUR;
    sampleFrequency = SAMPLE_FREQUENCY_LAST_ONE_HOUR;
  }

  // We need to manually add the missing data points due to the shutdown of VM

  const operateMetricRawData = (metricRawData) =>
    addMissingDataPoint(
      jointDataPointBaseonTimeSeries(metricRawData),
      queryStartingTime,
      sampleDuration,
      sampleFrequency,
    );

  const volumeUsedOperated = operateMetricRawData(
    volumeMetricGraphData?.volumeUsed,
  );
  const volumeLatencyOperated = operateMetricRawData(
    volumeMetricGraphData?.volumeLatency,
  );
  const volumeThroughputWriteOperated = operateMetricRawData(
    volumeMetricGraphData?.volumeThroughputWrite,
  );
  const volumeThroughputReadOperated = operateMetricRawData(
    volumeMetricGraphData?.volumeThroughputRead,
  );
  const volumeIOPSReadOperated = operateMetricRawData(
    volumeMetricGraphData?.volumeIOPSRead,
  );
  const volumeIOPSWriteOperated = operateMetricRawData(
    volumeMetricGraphData?.volumeIOPSWrite,
  );

  // slot[0] => timestamp
  // slot[1] => value
  const volumeUsageData = volumeUsedOperated?.map((slot) => {
    return {
      date: new Date(slot[0] * 1000), // convert from the RFC 3339 to time in JS
      y:
        slot[1] === null
          ? null
          : Math.round((slot[1] / volumeStorageCapacity) * 100),
    };
  });

  const volumeLatencyData = volumeLatencyOperated?.map((slot) => {
    return {
      date: new Date(slot[0] * 1000),
      y: slot[1] === null ? null : Math.round(slot[1] * 1000000),
    };
  });

  const volumeThroughputWriteData = volumeThroughputWriteOperated?.map(
    (slot) => {
      return {
        date: new Date(slot[0] * 1000),
        write: slot[1] === null ? null : slot[1] / 1000000,
        type: 'write',
      };
    },
  );

  const volumeThroughtReadData = volumeThroughputReadOperated?.map((slot) => {
    return {
      date: new Date(slot[0] * 1000),
      read: slot[1] === null ? null : slot[1] / 1000000,
      type: 'read',
    };
  });

  const volumeIOPSReadData = volumeIOPSReadOperated?.map((slot) => {
    return {
      date: new Date(slot[0] * 1000),
      read: slot[1] === null ? null : slot[1],
      type: 'read',
    };
  });

  const volumeIOPSWriteData = volumeIOPSWriteOperated?.map((slot) => {
    return {
      date: new Date(slot[0] * 1000),
      write: slot[1] === null ? null : slot[1],
      type: 'write',
    };
  });

  const volumeThroughputData = volumeThroughputWriteData?.concat(
    volumeThroughtReadData,
  );
  const volumeIOPSData = volumeIOPSWriteData?.concat(volumeIOPSReadData);

  const xAxis = {
    field: 'date',
    type: 'temporal',
    axis: {
      // Refer to all the available time format: https://github.com/d3/d3-time-format#locale_format
      format: '%m/%d %H:%M',
      // Boolean value that determines whether the axis should include ticks.
      ticks: true,
      tickCount: 4,
      labelAngle: -50,
      labelColor: '#a8b5c1',
    },
    title: null,
  };

  const yAxisThroughput = [
    {
      field: 'write',
      type: 'quantitative',
      // automatically add the unit for y axis labels: display 40k instead of 40000.  axis: { title: null, format: '~s' },
      axis: { title: null },
    },
    {
      field: 'read',
      type: 'quantitative',
      axis: { title: null },
    },
  ];

  const yAxisIOPS = [
    {
      field: 'write',
      type: 'quantitative',
      axis: { title: null },
    },
    {
      field: 'read',
      type: 'quantitative',
      axis: { title: null },
    },
  ];

  const yAxisUsauge = [
    {
      field: 'y',
      type: 'quantitative',
      axis: { title: null },
      // the max value of usage chart should always be 100%
      scale: { domain: [0, 100] },
    },
  ];

  const yAxisLatency = [
    {
      field: 'y',
      type: 'quantitative',
      axis: { title: null },
    },
  ];

  const colorUsage = {
    field: 'type',
    type: 'nominal',
    legend: null,
    domain: ['y'],
    scale: {
      range: ['#6ED0E0'],
    },
  };

  const colorLatency = {
    field: 'type',
    type: 'nominal',
    legend: null,
    domain: ['y'],
    scale: {
      range: ['#BA43A9'],
    },
  };

  const colorThroughput = {
    field: 'type',
    type: 'nominal',
    legend: {
      direction: 'horizontal',
      orient: 'bottom',
      title: null,
      symbolType: 'stroke',
      labelFontSize: 15,
      columnPadding: 50,
      symbolStrokeWidth: 5,
    },
    domain: ['write', 'read'],
    scale: {
      range: ['#73BF69', '#E0B400'],
    },
  };

  const colorIOPS = {
    field: 'type',
    type: 'nominal',
    legend: {
      direction: 'horizontal',
      orient: 'bottom',
      title: null,
      symbolType: 'stroke',
      labelFontSize: 15,
      columnPadding: 50,
      symbolStrokeWidth: 5,
    },
    domain: ['write', 'read'],
    scale: {
      range: ['#73BF69', '#E0B400'],
    },
  };

  // the time span of metrics graph, by default is `Last 24 hours`
  const metricsTimeSpanItems = [
    {
      label: LAST_SEVEN_DAYS,
      onClick: () => {
        dispatch(updateVolumeStatsAction({ metricsTimeSpan: LAST_SEVEN_DAYS }));
        updateMetricsGraph();
      },
      selected: metricsTimeSpan === LAST_SEVEN_DAYS,
    },
    {
      label: LAST_TWENTY_FOUR_HOURS,
      onClick: () => {
        dispatch(
          updateVolumeStatsAction({ metricsTimeSpan: LAST_TWENTY_FOUR_HOURS }),
        );
        updateMetricsGraph();
      },
      selected: metricsTimeSpan === LAST_TWENTY_FOUR_HOURS,
    },
    {
      label: LAST_ONE_HOUR,
      onClick: () => {
        dispatch(updateVolumeStatsAction({ metricsTimeSpan: LAST_ONE_HOUR }));
        updateMetricsGraph();
      },
      selected: metricsTimeSpan === LAST_ONE_HOUR,
    },
  ];

  const metricsTimeSpanDropdownItems = metricsTimeSpanItems?.filter(
    (mTS) => mTS.label !== metricsTimeSpan,
  );

  return (
    <MetricGraphCardContainer>
      <MetricGraphTitle>
        {intl.translate('metrics')}
        {volumeCondition === VOLUME_CONDITION_LINK && (
          <Dropdown
            items={metricsTimeSpanDropdownItems}
            text={metricsTimeSpan}
            size="smaller"
          />
        )}
      </MetricGraphTitle>
      {volumeCondition === VOLUME_CONDITION_LINK ? (
        <GraphsContainer>
          <RowGraphContainer>
            <UsageGraph>
              <GraphTitle>USAGE (%)</GraphTitle>
              {volumeUsageData && (
                <LineChart
                  id={'volume_usage_id'}
                  data={volumeUsageData}
                  xAxis={xAxis}
                  yAxis={yAxisUsauge}
                  color={colorUsage}
                  width={285}
                  height={80}
                  tooltip={false}
                />
              )}
            </UsageGraph>
            <LatencyGraph>
              <GraphTitle>LATENCY (µs) </GraphTitle>
              {volumeLatencyData && (
                <LineChart
                  id={'volume_latency_id'}
                  data={volumeLatencyData}
                  xAxis={xAxis}
                  yAxis={yAxisLatency}
                  color={colorLatency}
                  width={285}
                  height={80}
                  tooltip={false}
                />
              )}
            </LatencyGraph>
          </RowGraphContainer>
          <SecondRowGraphContainer>
            <TroughputGraph>
              <GraphTitle>THROUGHPUT (MB/s)</GraphTitle>
              {volumeThroughputData && (
                <LineChart
                  id={'volume_throughput_id'}
                  data={volumeThroughputData}
                  xAxis={xAxis}
                  yAxis={yAxisThroughput}
                  color={colorThroughput}
                  width={285}
                  height={80}
                  tooltip={false}
                />
              )}
            </TroughputGraph>
            <IOPSGraph>
              <GraphTitle>IOPS</GraphTitle>
              {volumeIOPSData && (
                <LineChart
                  id={'volume_IOPS_id'}
                  data={volumeIOPSData}
                  xAxis={xAxis}
                  yAxis={yAxisIOPS}
                  color={colorIOPS}
                  width={285}
                  height={80}
                  tooltip={false}
                />
              )}
            </IOPSGraph>
          </SecondRowGraphContainer>
        </GraphsContainer>
      ) : (
        <NoMetricsText>{intl.translate('volume_is_not_bound')}</NoMetricsText>
      )}
    </MetricGraphCardContainer>
  );
};

export default MetricGraphCard;