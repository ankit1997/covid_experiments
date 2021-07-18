import { Component, OnInit, ViewChild } from '@angular/core';
import { BackendService } from './backend.service';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css'],
})
export class AppComponent implements OnInit {
  options: any = {
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
  data: any = {};
  stepData: any = { datasets: [{ data: [], pointBackgroundColor: 'red' }] };
  numSteps: number = 0;
  step: number = -1;
  firstTime: boolean = true;

  @ViewChild('chart') chart: any;

  constructor(private backendService: BackendService) {}

  ngOnInit() {
    this.reloadData();
    setInterval(() => {
      this.setNextStepData();
      this.chart.chart.update();
    }, 500);
  }

  getBoxData() {
    const locations = this.data['locations'];
    const numLocations = locations[0].length;
    let boxes: any[] = [];

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
        borderColor: '#ffa500ff',
        borderWidth: 1,
        lineTension: 0,
      };
      boxes.push(box);
    }

    return boxes;
  }

  setNextStepData() {
    this.step += 1;

    const numAgents = this.data['num_agents'];
    const startInd = this.step * numAgents;
    const endInd = startInd + numAgents;
    const pos = this.data['pos'].slice(startInd, endInd);

    this.stepData.datasets[0].data = pos.map((p: number[]) => {
      return { x: p[0], y: p[1] };
    });

    if (this.firstTime) {
      const boxes: any[] = this.getBoxData();
      this.stepData.datasets.push(...boxes);
      this.firstTime = false;
    }

    if (this.step == this.numSteps) {
      this.step = -1;
    }
  }

  reloadData() {
    this.backendService.reloadData().subscribe((result) => {
      this.data = result;
      this.numSteps = this.data.step[this.data.step.length - 1];
    });
  }
}
