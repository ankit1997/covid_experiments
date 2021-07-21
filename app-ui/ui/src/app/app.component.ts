import { Component, OnInit, ViewChild } from '@angular/core';
import { BackendService } from './backend.service';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css'],
})
export class AppComponent implements OnInit {
  step: number = -1;

  // happy: any;
  // sad: any;

  @ViewChild('chart') chart: any;

  constructor(private backendService: BackendService) {
    // this.happy = new Image();
    // this.sad = new Image();
    // this.happy.src = 'assets/images/happy.png';
    // this.sad.src = 'assets/images/dissapointment.png';
  }

  ngOnInit() {}
}
