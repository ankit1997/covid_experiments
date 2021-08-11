import { Component, Input, ViewChild, OnInit } from '@angular/core';
import { BackendService } from '../backend.service';
import { MessageService } from 'primeng/api';
// import { Chart } from 'chart.js';

@Component({
  selector: 'app-simulation',
  templateUrl: './simulation.component.html',
  styleUrls: ['./simulation.component.css'],
  providers: [MessageService],
})
export class SimulationComponent implements OnInit {
  @Input('width') width: number = 100;
  @Input('height') height: number = 100;
  @ViewChild('scatterChart') scatterChart: any;
  @ViewChild('plotChart') plotChart: any;

  blockedDocument: boolean = false;
  onOff: boolean = false;
  params: any = {
    model_name: 'Model-A',
    num_agents: 200,
    num_days: 200,
    num_steps_in_day: 24,
    infection_radius: 0.5,
    initial_infections: 20,
    percentage_masked: 50.0,
    location: {
      num_houses: 120,
      num_hospitals: 10,
      num_empty: 270,
      map_dimensions: '20 x 20',
      capacity: {
        H: 10,
        '+': 50,
        O: 70,
      },
    },
    probabilities: {
      prob_visit_hospital: [],
    },
    percentage_vaccinated: [10.0, 0.0],
  };

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
    animation: {
      duration: 2000,
    },
    // onClick: (event: any, item: any) => {
    //   console.log(event);
    //   console.log(item);
    // },
  };
  plotOptions = {
    scales: {
      xAxes: [
        {
          display: true,
          scaleLabel: {
            display: true,
            labelString: 'Hour',
          },
        },
      ],
      yAxes: [
        {
          display: true,
          scaleLabel: {
            display: true,
            labelString: '# of agents',
          },
        },
      ],
    },
    tooltips: {
      enabled: false,
    },
    legend: {
      onClick: (e: any, legendItem: any, legend: any) => {
        if (this.backendService.hiddenStates.has(legendItem.text)) {
          this.backendService.hiddenStates.delete(legendItem.text);
        } else {
          this.backendService.hiddenStates.add(legendItem.text);
        }
        // if (
        //   Chart.defaults.global.legend &&
        //   Chart.defaults.global.legend.onClick
        // ) {
        //   Chart.defaults.global.legend.onClick(e, legendItem);
        // }
      },
    },
  };
  loading: boolean = false;
  data: any = {};
  stepData: any = {
    datasets: [
      {
        data: [],
        pointBackgroundColor: 'red',
        tension: 1.5,
        cubicInterpolationMode: 'monotone',
      },
    ],
  };
  stepDataHistory: any[] = [];
  plotDataMaxVal: any = -1;
  plotData: any = {
    labels: [],
    datasets: [
      {
        label: BackendService.SUSCEPTIBLE,
        data: [],
        borderColor: this.backendService.getColorFromInfectionStatus(
          BackendService.SUSCEPTIBLE
        ),
        pointRadius: 0,
        cubicInterpolationMode: 'monotone',
        tension: 0.4,
        borderWidth: 2,
      },
      {
        label: BackendService.ASYMPTOMATIC,
        data: [],
        borderColor: this.backendService.getColorFromInfectionStatus(
          BackendService.ASYMPTOMATIC
        ),
        pointRadius: 0,
        cubicInterpolationMode: 'monotone',
        tension: 0.4,
        borderWidth: 2,
      },
      {
        label: BackendService.MILD,
        data: [],
        borderColor: this.backendService.getColorFromInfectionStatus(
          BackendService.MILD
        ),
        pointRadius: 0,
        cubicInterpolationMode: 'monotone',
        tension: 0.4,
        borderWidth: 2,
      },
      {
        label: BackendService.INFECTED,
        data: [],
        borderColor: this.backendService.getColorFromInfectionStatus(
          BackendService.INFECTED
        ),
        pointRadius: 0,
        cubicInterpolationMode: 'monotone',
        tension: 0.4,
        borderWidth: 2,
      },
      {
        label: BackendService.SEVERE,
        data: [],
        borderColor: this.backendService.getColorFromInfectionStatus(
          BackendService.SEVERE
        ),
        pointRadius: 0,
        cubicInterpolationMode: 'monotone',
        tension: 0.4,
        borderWidth: 2,
      },
      {
        label: BackendService.HOSPITALIZED,
        data: [],
        borderColor: this.backendService.getColorFromInfectionStatus(
          BackendService.HOSPITALIZED
        ),
        pointRadius: 0,
        cubicInterpolationMode: 'monotone',
        tension: 0.4,
        borderWidth: 2,
      },
      {
        label: BackendService.RECOVERED,
        data: [],
        borderColor: this.backendService.getColorFromInfectionStatus(
          BackendService.RECOVERED
        ),
        pointRadius: 0,
        cubicInterpolationMode: 'monotone',
        tension: 0.4,
        borderWidth: 2,
      },
      {
        label: BackendService.DECEASED,
        data: [],
        borderColor: this.backendService.getColorFromInfectionStatus(
          BackendService.DECEASED
        ),
        pointRadius: 0,
        cubicInterpolationMode: 'monotone',
        tension: 0.4,
        borderWidth: 2,
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
  currentStep: number = -1;
  latestStep: number = 0;
  numSteps: number = 0;
  step: number = -1;
  day: number = 0;
  modelInitiated: boolean = false;
  simulationEnded: boolean = false;
  history_limit: number = 10;

  constructor(
    private backendService: BackendService,
    private messageService: MessageService
  ) {}

  ngOnInit(): void {
    this.params.probabilities.prob_visit_hospital = [];
    for (let i in BackendService.INFECTION_STATUS) {
      this.params.probabilities.prob_visit_hospital.push({
        status: BackendService.INFECTION_STATUS[i],
        prob: 0.2,
      });
    }

    setInterval(() => {
      if (this.onOff && !this.simulationEnded) {
        this.stepModel();
        this.currentStep += 1;
      }
    }, 300);
  }

  initModel() {
    const validationError = this.validateParams();
    if (validationError != null) {
      this.showMessage(false, validationError);
      return;
    }
    let params = this.formatParams();
    let payload = {
      params: params,
    };
    this.blockedDocument = true;
    this.backendService.initModel(payload).subscribe(
      (result) => {
        this.showMessage(result.success, result.message);
        if (result.success) {
          this.getWorldMap();
          this.numSteps = this.params.num_days * this.params.num_steps_in_day;
          this.modelInitiated = true;
        }
        this.blockedDocument = false;
      },
      (error) => {
        this.blockedDocument = false;
        console.log(error);
      }
    );
  }

  terminateModel() {
    // Terminate the model with name as set in the input field
    this.blockedDocument = true;
    this.backendService
      .terminateModel(this.params.model_name)
      .subscribe((result) => {
        this.showMessage(result.success, result.message);
        // after termination of model, clear the history
        this.stepDataHistory = [];
        this.modelInitiated = false;
        this.blockedDocument = false;
        this.onOff = false;
        this.currentStep = -1;
        for (let dataset of this.plotData.datasets) {
          dataset.data = [];
        }
      });
  }

  updateModel() {
    let params = this.formatParams();
    let payload = {
      params: params,
    };
    this.backendService
      .updateModel(this.params.model_name, payload)
      .subscribe((result: any) => {
        console.log(result);
      });
  }

  getWorldMap() {
    this.backendService
      .worldMap(this.params.model_name)
      .subscribe((result: any) => {
        if (result && result.length > 0) {
          this.drawWorldMap(result);
        } else {
          this.showMessage(false, 'Unexpected error, check server logs.');
        }
      });
  }

  loadAgentData(data: any) {
    this.stepData.datasets[0].data = data.positions.map((p: number[]) => {
      return { x: p[0], y: p[1] };
    });
    this.stepData.datasets[0].pointStyle = data.home_loc_id.map(
      (h: number, i: number) => {
        return h == data.current_loc_id[i] ? 'triangle' : 'circle';
      }
    );
    this.stepData.datasets[0].pointBackgroundColor = data.infection_status.map(
      (i: string) => {
        return this.backendService.getColorFromInfectionStatus(i);
      }
    );
    this.stepData.datasets[0].pointRadius = data.infection_status.map(
      (i: string) => {
        return this.backendService.getPointRadiusFromInfectionStatus(i);
      }
    );
    this.stepData.datasets[0].borderColor = data.infection_status.map(
      (inf: string, i: number) => {
        return this.backendService.getPointBorderColor(
          inf,
          data.mask[i],
          data.vaccination[i]
        );
      }
    );
    this.stepData.datasets[0].borderWidth = data.infection_status.map(
      (inf: string, i: number) => {
        return this.backendService.getPointBorderWidth(
          inf,
          data.mask[i],
          data.vaccination[i]
        );
      }
    );
  }

  stepModel() {
    if (!this.modelInitiated) {
      this.getWorldMap();
      this.modelInitiated = true;
    }
    if (this.currentStep in this.stepDataHistory) {
      this.day = Number.parseFloat((this.currentStep / 24).toPrecision(3));
      this.drawAgents(undefined, this.currentStep);
      return;
    }
    // const startTime = new Date().getTime();
    this.backendService
      .step(this.params.model_name)
      .subscribe((result: any) => {
        if (result.success === false && result.message === 'END') {
          this.simulationEnded = true;
          this.showMessage(true, 'Simulation completed');
          return;
        } else if (result.success === false) {
          this.simulationEnded = true;
          this.showMessage(false, 'Unexpected error, check server logs.');
        } else if (result) {
          this.currentStep = result.step;
          this.latestStep = result.step;
          this.day = Number.parseFloat((this.currentStep / 24).toPrecision(3));
          this.stepDataHistory[this.currentStep] = result;
          if (
            this.latestStep - this.history_limit in this.stepDataHistory &&
            this.stepDataHistory[this.latestStep - this.history_limit] !==
              undefined
          ) {
            for (
              let i = this.latestStep - this.history_limit - 1;
              i >= 0;
              i--
            ) {
              if (this.stepDataHistory[i] === undefined) {
                break;
              }
              this.stepDataHistory[i] = undefined;
            }
          }
          this.drawAgents(JSON.parse(JSON.stringify(result)));
          // const diffTime = new Date().getTime() - startTime;
          // const wait = diffTime < 500 ? 500 - diffTime : 10;
          // setTimeout(() => {
          //   this.stepModel();
          // }, wait);
        }
      });
  }

  drawStatsPlot(data: any, latest: boolean) {
    if (latest) {
      let num = 0;
      for (let dataset of this.plotData.datasets) {
        if (dataset.label === 'Step') {
          continue;
        }
        let state = dataset.label;
        let value = data.count[state] ? data.count[state] : 0;
        this.plotDataMaxVal = Math.max(this.plotDataMaxVal, value);
        dataset.data.push(value);
        dataset.borderColor = this.backendService.getColorFromInfectionStatus(
          dataset.label
        );
        if (
          dataset.borderColor.length === 9 &&
          dataset.borderColor.endsWith('00')
        ) {
          dataset.backgroundColor = '#00000000';
        } else {
          dataset.backgroundColor = '#01010101';
        }
        num = dataset.data.length;
      }
      this.plotData.labels = [...Array(num + 5).keys()];
      this.plotChart.chart.update();
    }
    // Draw vertical line specifying step
    this.plotData.datasets[this.plotData.datasets.length - 1].data = [
      { x: data.step, y: 0 },
      { x: data.step, y: this.plotDataMaxVal + 20 },
    ];
    this.plotChart.chart.update();
  }

  drawWorldMap(locations: any[]) {
    const xMin = Math.min(...locations.map((loc) => loc['x_min']));
    const xMax = Math.max(...locations.map((loc) => loc['x_max']));
    const yMin = Math.min(...locations.map((loc) => loc['y_min']));
    const yMax = Math.max(...locations.map((loc) => loc['y_max']));

    // Create array of boxes. Initialize with a big box around the whole chart
    let boxes: any[] = [
      {
        data: [
          { x: xMin, y: yMin },
          { x: xMax, y: yMin },
          { x: xMax, y: yMax },
          { x: xMin, y: yMax },
          { x: xMin, y: yMin },
        ],
        type: 'line',
        borderColor: BackendService.BLACK,
        pointRadius: 0,
        borderWidth: 3,
        lineTension: 0,
      },
    ];

    // For all locations in the data, create a box around the location
    for (let loc of locations) {
      const xmin = loc.x_min;
      const xmax = loc.x_max;
      const ymin = loc.y_min;
      const ymax = loc.y_max;
      const box = {
        label: this.backendService.getLocationType(loc.type),
        data: [
          { x: xmin, y: ymin },
          { x: xmax, y: ymin },
          { x: xmax, y: ymax },
          { x: xmin, y: ymax },
          { x: xmin, y: ymin },
        ],
        type: 'line',
        backgroundColor: this.backendService.getBoxColorFromLocationType(
          loc.type
        ),
        borderColor: BackendService.BLACK,
        pointRadius: 0,
        borderWidth: 1,
        lineTension: 0, // This makes the lines straight instead of curvy
      };
      boxes.push(box);
    }
    this.stepData.datasets.length = 1;
    this.stepData.datasets.push(...boxes);
    this.scatterChart.chart.update();
  }

  drawAgents(data: any, step?: number) {
    let dataToLoad = data;
    if (step && step in this.stepDataHistory) {
      if (this.stepDataHistory[step] === undefined) {
        this.drawStatsPlot({ step: step }, false);
      } else {
        dataToLoad = this.stepDataHistory[step];
        this.loadAgentData(dataToLoad);
        this.drawStatsPlot(dataToLoad, false);
        this.scatterChart.chart.update();
      }
    } else {
      this.loadAgentData(dataToLoad);
      this.drawStatsPlot(dataToLoad, true);
      this.scatterChart.chart.update();
      this.currentStep += 1;
    }
  }

  handlePlayPauseClick($event: any) {
    if ($event === 'PLAY_PAUSE') {
      this.onOff = !this.onOff;
    } else if ($event === 'PREVIOUS') {
      this.onOff = false;
      this.currentStep = Math.max(1, this.currentStep - 1);
      this.stepModel();
    } else if ($event === 'NEXT') {
      this.onOff = false;
      this.currentStep = Math.max(1, this.currentStep + 1);
      this.stepModel();
    } else if ($event === 'LATEST') {
      this.onOff = false;
      this.currentStep = this.latestStep + 1;
      this.stepModel();
    } else if ($event === 'FIRST') {
      this.onOff = false;
      this.currentStep = Math.max(1, this.currentStep - this.history_limit);
      this.stepModel();
    }
  }

  formatParams() {
    let paramsCopy = JSON.parse(JSON.stringify(this.params));
    paramsCopy.location.map_dimensions = this._getMapDimensionsFromString(
      paramsCopy.location.map_dimensions
    );
    return paramsCopy;
  }

  parseParams() {
    this.params.location.map_dimensions =
      this.params.location.map_dimensions[0] +
      ' x ' +
      this.params.location.map_dimensions[1];
  }

  _getMapDimensionsFromString(s: string) {
    return s.split(' x ').map((i: string) => Number.parseInt(i));
  }

  validateParams(): string | null {
    const mapDimen = this._getMapDimensionsFromString(
      this.params.location.map_dimensions
    );
    const num_blocks = mapDimen[0] * mapDimen[1];
    if (
      this.params.location.num_houses +
        this.params.location.num_hospitals +
        this.params.location.num_empty !=
      num_blocks
    ) {
      return 'Invalid map dimension';
    }
    return null;
  }

  showMessage(success: boolean, message: string) {
    this.messageService.add({
      severity: success ? 'success' : 'error',
      summary: success ? 'Success' : 'Error',
      detail: message,
    });
  }
}
