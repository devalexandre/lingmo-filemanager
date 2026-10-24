cmake_minimum_required(VERSION 3.14)

project(filemanager LANGUAGES CXX)

set(CMAKE_INCLUDE_CURRENT_DIR ON)

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 COMPONENTS Core DBus Quick LinguistTools Core5Compat REQUIRED)
# find_package(LingmoUI REQUIRED)

find_package(KF6KIO REQUIRED)
find_package(KF6Solid REQUIRED)
find_package(KF6WindowSystem REQUIRED)
find_package(KF6Config REQUIRED)
find_package(KF6Service REQUIRED)
find_package(KF6XmlGui REQUIRED)

find_package(LingmoUI3 REQUIRED)

# Optional: duration, dimensions, artist... in the preview pane
find_package(KF6FileMetaData QUIET)

# Optional: first page of PDFs in the preview pane (poppler-qt6)
find_package(ECM QUIET NO_MODULE)
if(ECM_FOUND)
  list(APPEND CMAKE_MODULE_PATH ${ECM_FIND_MODULE_DIR})
endif()
find_package(Poppler QUIET COMPONENTS Qt6)

qt6_add_dbus_adaptor(DBUS_SOURCES
                     com.lingmo.FileManager.xml
                     application.h Application)

add_executable(lingmo-filemanager
  main.cpp
  application.cpp
  window.cpp
  dbusinterface.cpp

  draganddrop/declarativedroparea.cpp
  draganddrop/declarativedragdropevent.cpp
  draganddrop/declarativemimedata.cpp

  model/foldermodel.cpp
  model/placesmodel.cpp
  model/placesitem.cpp
  model/pathbarmodel.cpp
  model/dirlister.cpp
  model/positioner.cpp
  model/searchmodel.cpp

  cio/cfilejob.cpp
  cio/cfilesizejob.cpp

  dialogs/createfolderdialog.cpp
  dialogs/filepropertiesdialog.cpp
  dialogs/openwithdialog.cpp
  widgets/rubberband.cpp
  widgets/itemviewadapter.cpp

  desktop/desktop.cpp
  desktop/desktopview.cpp
  desktop/desktopsettings.cpp
  desktop/dockdbusinterface.cpp

  helper/archivemanager.cpp
  helper/nearbyshare.cpp
  helper/datehelper.cpp
  helper/pathhistory.cpp
  helper/fm.cpp
  helper/shortcut.cpp
  helper/filelauncher.cpp
  helper/keyboardsearchmanager.cpp
  helper/placeshelper.cpp
  helper/islandjobtracker.cpp

  mimetype/mimeappmanager.cpp
  mimetype/xdgdesktopfile.cpp

  thumbnailer/thumbnailprovider.cpp
  thumbnailer/thumbnailcache.cpp

  desktopiconprovider.cpp

  qml.qrc

  ${DBUS_SOURCES}
)

target_link_libraries(lingmo-filemanager
  PRIVATE
  Qt6::Core
  Qt6::DBus
  Qt6::Quick
  Qt6::Core5Compat

  KF6::KIOCore
  KF6::Service
  KF6::KIOFileWidgets
  KF6::KIOWidgets
  KF6::Solid
  KF6::WindowSystem
  KF6::ConfigCore
  KF6::XmlGui

  LingmoUI3
)

if(Poppler_Qt6_FOUND)
  target_sources(lingmo-filemanager PRIVATE thumbnailer/pdfpreviewprovider.cpp)
  target_link_libraries(lingmo-filemanager PRIVATE Poppler::Qt6)
  target_compile_definitions(lingmo-filemanager PRIVATE HAVE_POPPLER)
  message(STATUS "PDF preview: poppler-qt6")
else()
  message(STATUS "PDF preview: disabled (poppler-qt6 not found)")
endif()

if(KF6FileMetaData_FOUND)
  target_link_libraries(lingmo-filemanager PRIVATE KF6::FileMetaData)
  target_compile_definitions(lingmo-filemanager PRIVATE HAVE_KFILEMETADATA)
endif()

file(GLOB TS_FILES translations/*.ts)
foreach(filepath ${TS_FILES})
    string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/" "" filename ${filepath})
    list(APPEND ts_files_replaced ${filename})
endforeach()
qt_add_translation(QM_FILES ${ts_files_replaced})

add_custom_target(translations ALL DEPENDS ${QM_FILES} SOURCES ${ts_files_replaced})

install(TARGETS lingmo-filemanager RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES lingmo-filemanager.desktop DESTINATION "/usr/share/applications")
install(FILES ${QM_FILES} DESTINATION /usr/share/lingmo-filemanager/translations)
