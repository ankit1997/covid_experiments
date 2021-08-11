import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { HttpClientModule } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';

import { AppComponent } from './app.component';
import { SimulationComponent } from './simulation/simulation.component';
import { ParamsComponent } from './params/params.component';

import { ChartModule } from 'primeng/chart';
import { ButtonModule } from 'primeng/button';
import { SliderModule } from 'primeng/slider';
import { PanelModule } from 'primeng/panel';
import { AccordionModule } from 'primeng/accordion';
import { InputTextModule } from 'primeng/inputtext';
import { InputNumberModule } from 'primeng/inputnumber';
import { InputMaskModule } from 'primeng/inputmask';
import { ToggleButtonModule } from 'primeng/togglebutton';
import { ToastModule } from 'primeng/toast';
import { OverlayPanelModule } from 'primeng/overlaypanel';
import { TooltipModule } from 'primeng/tooltip';
import { BlockUIModule } from 'primeng/blockui';

@NgModule({
  declarations: [AppComponent, SimulationComponent, ParamsComponent],
  imports: [
    BrowserModule,
    ChartModule,
    ButtonModule,
    SliderModule,
    PanelModule,
    AccordionModule,
    InputTextModule,
    InputNumberModule,
    InputMaskModule,
    ToastModule,
    OverlayPanelModule,
    ToggleButtonModule,
    TooltipModule,
    BlockUIModule,
    HttpClientModule,
    BrowserAnimationsModule,
    FormsModule,
  ],
  providers: [],
  bootstrap: [AppComponent],
})
export class AppModule {}
