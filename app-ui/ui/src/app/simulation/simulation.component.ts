import { Component, Input, ViewChild, OnInit } from '@angular/core';
import { BackendService } from '../backend.service';

@Component({
  selector: 'app-simulation',
  templateUrl: './simulation.component.html',
  styleUrls: ['./simulation.component.css'],
})
export class SimulationComponent implements OnInit {
  @Input('getUrl') getUrl: string = '';
  @Input('onOff') onOff: boolean = true; // whether to run the simulation or not
  @Input('width') width: number = 100;
  @Input('height') height: number = 100;
  @ViewChild('scatterChart') scatterChart: any;
  @ViewChild('plotChart') plotChart: any;

  scatterOptions: any = {
    scales: {
      xAxes: [
        {
          display: false,
        },
      ],
      yAxes: [
        {
          display: false,
        },
      ],
    },
    legend: {
      display: false,
    },
    tooltips: {
      enabled: false,
    },
  };
  plotOptions = {
    scales: {
      xAxes: [
        {
          display: true,
        },
      ],
      yAxes: [
        {
          display: true,
        },
      ],
    },
    tooltips: {
      enabled: false,
    },
  };
  loading: boolean = false;
  data: any = {};
  stepData: any = {
    datasets: [{ data: [], pointBackgroundColor: 'red' }],
  };
  plotData: any = {
    labels: [],
    datasets: [
      {
        label: 'Susceptible',
        data: [],
        borderColor: this.backendService.getColorFromInfectionStatus('S'),
        pointRadius: 0,
      },
      {
        label: 'Undetected',
        data: [],
        borderColor: this.backendService.getColorFromInfectionStatus('IU'),
        pointRadius: 0,
      },
      {
        label: 'Detected',
        data: [],
        borderColor: this.backendService.getColorFromInfectionStatus('ID'),
        pointRadius: 0,
      },
      {
        label: 'Recovered',
        data: [],
        borderColor: this.backendService.getColorFromInfectionStatus('R'),
        pointRadius: 0,
      },
      {
        label: 'Deceased',
        data: [],
        borderColor: this.backendService.getColorFromInfectionStatus('D'),
        pointRadius: 0,
      },
      {
        label: 'Step',
        data: [],
        borderColor: 'black',
        borderWidth: 1,
        pointRadius: 0,
      },
    ],
  };
  numSteps: number = 0;
  step: number = -1;
  day: number = 0;
  firstTime: boolean = true;

  constructor(private backendService: BackendService) {}

  ngOnInit(): void {
    // Get the data from backend service
    this.reloadData();
    // At regular interval, calculate next step data and update chart
    setInterval(() => {
      if (Object.keys(this.data).length && this.onOff) {
        this.setNextStepData();
      }
    }, 400);
  }

  reloadData() {
    this.loading = true;
    this.backendService.reloadData(this.getUrl).subscribe((result: any) => {
      this.data = result;
      this.numSteps = this.data.step[this.data.step.length - 1];
      this.loading = false;
      this.setStatsData();
    });
  }

  setStatsData() {
    this.plotData.labels = [...Array(this.data['model_stats'].length).keys()];
    for (let i = 0; i <= 4; i++) {
      this.plotData.datasets[i].data = this.data['model_stats'].map(
        (val: number[]) => val[i]
      );
    }
    this.plotChart.chart.update();
  }

  setNextStepData(step?: number) {
    // Calculate the next step's data for the chart to show. This is called repeatedly to animate the simulation
    if (step !== undefined) this.step = step;
    else this.step += 1;

    this.day = Number.parseFloat((this.step / 24).toPrecision(3));

    const numAgents = this.data['num_agents'];
    const startInd = this.step * numAgents;
    const endInd = startInd + numAgents;
    const pos = this.data['pos'].slice(startInd, endInd);
    const homeLoc = this.data['home_loc_ids'].slice(startInd, endInd);
    const currentLoc = this.data['current_loc_ids'].slice(startInd, endInd);
    const infectionStatus = this.data['infection_status'].slice(
      startInd,
      endInd
    );

    this.stepData.datasets[0].data = pos.map((p: number[]) => {
      return { x: p[0], y: p[1] };
    });
    this.stepData.datasets[0].pointStyle = homeLoc.map(
      (h: number, i: number) => {
        return h == currentLoc[i] ? 'triangle' : 'rect';
      }
    );
    this.stepData.datasets[0].pointBackgroundColor = infectionStatus.map(
      (i: string) => {
        return this.backendService.getColorFromInfectionStatus(i);
      }
    );
    this.stepData.datasets[0].pointRadius = 3;

    this.plotData.datasets[this.plotData.datasets.length - 1].data = [
      { x: this.step, y: 0 },
      { x: this.step, y: this.plotChart.chart.chart.scales['y-axis-0']['end'] },
    ];

    if (this.firstTime) {
      const boxes: any[] = this.getBoxData();
      this.stepData.datasets.push(...boxes);
      this.firstTime = false;
    }

    if (this.step == this.numSteps) {
      // At the last step, reset the counter
      this.step = -1;
    }

    // update/render the chart after data is updated
    this.scatterChart.chart.update();
    this.plotChart.chart.update();
  }

  getBoxData() {
    // Generate boxes in the chart to mark borders of location (e.g. house, hospital, road, etc.)

    const locations = this.data['locations'];
    const numLocations = locations[0].length;

    // Create array of boxes. Initialize with a big box around the whole chart
    let boxes: any[] = [
      {
        data: [
          { x: 0, y: 0 },
          { x: this.data['x_max'], y: 0 },
          { x: this.data['x_max'], y: this.data['y_max'] },
          { x: 0, y: this.data['y_max'] },
          { x: 0, y: 0 },
        ],
        type: 'line',
        borderColor: BackendService.BLACK,
        pointRadius: 0,
        borderWidth: 1,
        lineTension: 0,
      },
    ];

    // For all locations in the data, create a box around the location
    for (let i = 0; i < numLocations; i++) {
      const xmin = locations[0][i];
      const xmax = locations[1][i];
      const ymin = locations[2][i];
      const ymax = locations[3][i];
      const box = {
        data: [
          { x: xmin, y: ymin },
          { x: xmax, y: ymin },
          { x: xmax, y: ymax },
          { x: xmin, y: ymax },
          { x: xmin, y: ymin },
        ],
        type: 'line',
        backgroundColor: this.backendService.getBoxColorFromLocationType(
          locations[4][i]
        ),
        borderColor: this.backendService.getBoxBorderColorFromLocationType(
          locations[4][i]
        ),
        pointRadius: 0,
        borderWidth: 1,
        lineTension: 0, // This makes the lines straight instead of curvy
      };
      boxes.push(box);
    }

    // return the boxes
    return boxes;
  }

  sliderChange(event: any) {
    this.onOff = false;
    this.setNextStepData(event.value);
  }

  playButtonEvent(event: string) {
    if (event === 'next') {
      this.onOff = false;
      this.setNextStepData(this.step + 1);
    } else if (event == 'previous') {
      this.onOff = false;
      this.setNextStepData(this.step - 1);
    } else if (event == 'play_pause') {
      this.onOff = !this.onOff;
    }
  }
}
