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
          display: true,
        },
      ],
      yAxes: [
        {
          display: true,
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
  stepData: any = {
    datasets: [{ data: [], pointBackgroundColor: 'red' }],
  };
  numSteps: number = 0;
  step: number = -1;
  day: number = 0;
  firstTime: boolean = true;
  penguin: any;
  anim_onoff: boolean = true;

  @ViewChild('chart') chart: any;

  constructor(private backendService: BackendService) {
    this.penguin = new Image();
    this.penguin.src =
      'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAkGBwgHBgkIBwgKCgkLDRYPDQwMDRsUFRAWIB0iIiAdHx8kKDQsJCYxJx8fLT0tMTU3Ojo6Iys/RDM4QzQ5OjcBCgoKDQwNFQ8PGi4lHyU3LTc3Nzc3Kzc3NzcuLTA3LTc1NzcwLi03Kzc3Ky8tNy0uKy0rKystKysrKysrKysrLf/AABEIACAAIAMBEQACEQEDEQH/xAAYAAADAQEAAAAAAAAAAAAAAAADBQYHAv/EACcQAAIBAwIGAQUAAAAAAAAAAAECAwAEEQUSEyExMkFxQgYUIlFh/8QAGQEAAgMBAAAAAAAAAAAAAAAABAUBAgMA/8QAIBEAAgMAAgIDAQAAAAAAAAAAAQIAAxEEITFBEiJRMv/aAAwDAQACEQMRAD8A2q5uEt49zn0B5rK21al0yyIWOCJzrXElaOOWMMOqAgkUsfl3HsdCFClB5hYtWKOFlZTu5AE4Jq1fLtH9diQ1K+o2hlSZNyUyrcONEGZSpwye12aSS5kjRtu1dqn9HHWlvLfbMPqE0jFkPo119RXOvPa3ljwdPhbMTlMBMHw3yJGQfdbW3I1ZAlgudzv6m1DV9P1eGKx0r7yG4cb34RfK4A2gjt+RqOPYi15OK6e5eaJLKhhjl5syAP7xUcZ8sweDM7R9dgtehKXfFGcSL1/tU5qEP8v2Wob65Fltcq+VyA696+RQmZNyIaW5SLaCRvbtUdWNTIA2M9IRpLgSY/FBzNF8RSX30JhcesjO9SF7ZhcdmKYWIrLjTBSQepGXNhHcyZkizg4VwcMB75UvHGYeDCxdniFsLCO3kDCNVB7znLkezXDikkfIzmu2VlrJCIQsGAo8UwQKoxYI2k9z/9k=';
  }

  ngOnInit() {
    this.reloadData();
    setInterval(() => {
      if (Object.keys(this.data).length && this.anim_onoff) {
        this.setNextStepData();
      }
    }, 500);
  }

  getBoxData() {
    const locations = this.data['locations'];
    const numLocations = locations[0].length;
    let boxes: any[] = [];

    const gray = '#80808044';
    const blue = '#0000ff22';
    const white = '#ffffff44';
    const getColor = (locType: string) => {
      if (locType == 'o') return white;
      else if (locType == 'h') return blue;
      return white;
    };

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
        backgroundColor: getColor(locations[4][i]),
        borderWidth: 1,
        lineTension: 0,
      };
      boxes.push(box);
    }

    return boxes;
  }

  setNextStepData(step?: number) {
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
        return i == 'S' ? 'blue' : 'red';
      }
    );
    this.stepData.datasets[0].pointRadius = 3;

    if (this.firstTime) {
      const boxes: any[] = this.getBoxData();
      this.stepData.datasets.push(...boxes);
      this.firstTime = false;
    }

    if (this.step == this.numSteps) {
      this.step = -1;
    }

    this.chart.chart.update();
  }

  reloadData() {
    this.backendService.reloadData().subscribe((result) => {
      this.data = result;
      this.numSteps = this.data.step[this.data.step.length - 1];
    });
  }

  sliderChange(event: any) {
    this.anim_onoff = false;
    this.setNextStepData(event.value);
  }
}
