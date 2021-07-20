import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { HttpClientModule } from '@angular/common/http';
import { FormsModule } from '@angular/forms';

import { AppComponent } from './app.component';
import { ChartModule } from 'primeng/chart';
import { ButtonModule } from 'primeng/button';
import { SliderModule } from 'primeng/slider';

@NgModule({
  declarations: [AppComponent],
  imports: [
    BrowserModule,
    ChartModule,
    ButtonModule,
    SliderModule,
    HttpClientModule,
    FormsModule,
  ],
  providers: [],
  bootstrap: [AppComponent],
})
export class AppModule {}
