class ProjectsController < ApplicationController
  
  def index
    @projects = Project.all
    respond_to do |format|
      format.html
      format.xml {render xml: @projects}
    end
  end
  

  def sync
    #il Project è SEMPRE riferito al progetto presente su Freeagent, il quale ha l'attributo basecamp_id che funge da chiave
    project = Project.find(params[:id])

    #questa linea serve a trovare i todolist di un progetto di 
    @todo_lists = TodoList.find(:all, params: {project_id: project.basecamp_id})
    
    #inizializzo l'array per la mappatura todolist/task
    task_link = []
    
    #qui creo il task fasullo per raccogliere le timeentries che non hanno todolist su basecamp, ovvero con l'attributo todo_item_id nulla
    no_task_assigned = Task.new(name: "No task assigned")
    no_task_assigned.prefix_options = {project_id: project.id}
    no_task_assigned.save
    
    #qui creo i tasks di freeagent partendo dal progetto
    @todo_lists.each do |todo_list|
      task = Task.new(name: todo_list.name)
      task.prefix_options = {project_id: project.id}
      unless task.save
        redirect_to projects_url, notice: "Errore nella creazione dei tasks"
      end
      #qui sotto creo un portachiavi temporaneo per mappare i todolist (basecamp) e i task(freeagent), su di un array semplice.
      task_link << [todo_list.id.to_s, task.id]
    end
    
    #qui creo le timeentries
    @time_entries = collect_time_entries(project.basecamp_id)
    @time_entries.each do |time_entry|
      timeslip = Timeslip.new(project_id: project.id,
                              user_id:    "123039",
                              hours:      time_entry.hours,
                              dated_on:   time_entry.date,
                              task_id:    find_task_id(task_link, time_entry, no_task_assigned),
                              comment:    "[#{time_entry.description}]")
      unless timeslip.save
        redirect_to projects_url, notice: "Errore nella creazione delle timeslips"
      end
    end
    redirect_to projects_url, notice: "Sincronizzazione avvenuta"
  end
  
  protected
  
  def collect_time_entries project
    TimeEntry.find(:all, params: {project_id: project})
  end
  
  def find_task_id task_link, time_entry, no_task_assigned
    if time_entry.todo_item_id.nil?
      no_task_assigned.id
    else
      task_link.select{|id| TodoItem.find(time_entry.todo_item_id).todo_list_id.to_s == id[0]}[0][1]
    end
  end
end